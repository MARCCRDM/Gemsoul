-- lune run tests/kaiju_server_cases.luau <repo>
-- Mini kaiju on the server, against stand-in Roblox pieces (the real
-- Shared.Kaiju, KaijuFight, KaijuAbilities, KaijuFighter, KaijuServer and
-- KaijuWilds; Enemies, CombatServer, PlayerData and the models are
-- stand-ins): every E ability lands where it should; your kaiju comes out
-- in the Outpost (a starter the first time), fights creatures near you and
-- is credited to you, is hurt by element, knocked out and back; recall;
-- switching; infusing (health kept, knockouts revived with stones); wild kaiju take blows with the spread and their
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
	GetPlayerByUserId = function(_, id)
		for _, player in playerList do
			if player.UserId == id then
				return player
			end
		end
		return nil
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

local notes, fxs, socials = {}, {}, {}
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
	Social = {
		FireClient = function(_, player, kind, ...)
			table.insert(socials, { player, kind, ... })
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
	removeGems = function(player, ids)
		local gems, removed = profiles[player].Gems, 0
		for i = #gems, 1, -1 do
			if ids[gems[i].Id] then
				table.remove(gems, i)
				removed += 1
			end
		end
		return removed
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
	returnGem = function(player, gem)
		table.insert(profiles[player].Gems, gem)
		return true
	end,
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
-- (The wall clock moves with `now`: a knocked-out kaiju's revive time.)
clock.time = function()
	return 1700000000 + math.floor(now)
end
env = setmetatable({
	Color3 = Color3,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	UDim2 = roblox.UDim2,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
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
	-- (script.Parent.X, and further: script.Parent.Parent.World.X, by its name.)
	script = {
		Parent = setmetatable({}, {
			__index = function(_, key)
				local function path(name)
					return setmetatable({ Server = name }, {
						__index = function(_, sub)
							return path(sub)
						end,
					})
				end
				return path(key)
			end,
		}),
	},
	require = function(target)
		if type(target) == "string" then
			return shared(target)
		elseif rawget(target, "Shared") then
			return shared(rawget(target, "Shared"))
		end
		return serverModule(rawget(target, "Server"))
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
-- (A creature's comes "Sized": its size, then the effect.)
local function drew(kind)
	for _, entry in fxs do
		if entry[1] == kind or (entry[1] == "Sized" and entry[3] == kind) then
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

-- A kaiju's moves are its size (AbilityPlans are a player's): a half-size
-- caster's Supernova lands, and is drawn, half as wide, every effect of it
-- "Sized" for the client; a full-size one's reaches the foe further out.
local function halfCast(size)
	local plan = Kaiju.AbilityPlans.E_Supernova
	local hits = {}
	local foe = { Root = root(Vector3.new(0, 0, -5)), Name = "foe" }
	local near = { Root = root(Vector3.new(plan.Radius * 0.4, 0, -5)), Name = "near" }
	local wide = { Root = root(Vector3.new(plan.Radius * 0.8, 0, -5)), Name = "wide" }
	local caster = {
		Model = make("Model"),
		Root = root(Vector3.zero),
		Size = size,
		Element = "Fire",
		Ability = "E_Supernova",
		Damage = 100,
		Foes = function(center, radius)
			local list = {}
			for _, victim in { foe, near, wide } do
				if (victim.Root.Position - center).Magnitude <= radius then
					table.insert(list, victim)
				end
			end
			return list
		end,
		Hit = function(victim)
			hits[victim.Name] = true
		end,
		Alive = function()
			return true
		end,
	}
	table.clear(fxs)
	KaijuAbilities.cast(caster, foe)
	flush()
	return hits, plan
end
do
	local hits, plan = halfCast(0.5)
	check(hits.foe and hits.near and not hits.wide, "A half-size kaiju's blast didn't land half as wide")
	local shown = drew("TriadShow")
	check(shown ~= nil and shown[1] == "Sized" and shown[2] == 0.5, "A half-size kaiju's look wasn't sized")
	check(shown ~= nil and math.abs(shown[8] - plan.Radius * 0.5) < 1e-6, "Its look wasn't drawn as wide as it lands")
	for _, entry in fxs do
		check(entry[1] == "Sized" and entry[2] == 0.5, "A half-size kaiju's " .. tostring(entry[1]) .. " wasn't sized")
	end
	hits = halfCast(nil)
	check(hits.foe and hits.near and hits.wide, "A full-size blast didn't reach its whole radius")
	check(fxs[1] ~= nil and fxs[1][1] ~= "Sized", "A full-size caster's look was sized")
end

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
for _, name in { "KaijuRecall", "KaijuTeam", "KaijuActive", "KaijuInfuse", "KaijuAutoHeal", "KaijuTame", "KaijuRoll", "KaijuRollClaim" } do
	check(registered[name] ~= nil, name .. " isn't a request")
end

-- The starter roll: three kaiju, made once (asking again shows the same),
-- never the same kind and element twice; claimed, they all come out.
KaijuServer._upkeep(a, now)
local roster = Kaiju.roster(profiles[a])
check(Kaiju.count(roster) == 0 and Kaiju.rollsOwed(profiles[a]) == Kaiju.StarterTeam, "A kaiju before the roll")
do
	local rolled = registered.KaijuRoll(a)
	check(rolled.Ok and #rolled.Rolls == Kaiju.StarterTeam, "No starter roll")
	local rolledKinds = {}
	for _, entry in rolled.Rolls do
		check(
			Kaiju.Species[entry.Species] and Kaiju.isSoul(entry.Soul) and entry.Soul.Element == entry.Element,
			"A bad roll"
		)
		check(not rolledKinds[entry.Species .. entry.Element], "The same kaiju rolled twice")
		rolledKinds[entry.Species .. entry.Element] = true
	end
	check(registered.KaijuRoll(a).Rolls[1].Soul.Id == rolled.Rolls[1].Soul.Id, "Asking again rerolled")
	check(Kaiju.count(roster) == 0, "Rolling gave kaiju before the claim")
	check(registered.KaijuRollClaim(a).Ok, "Couldn't claim the roll")
	check(
		Kaiju.count(roster) == 3 and profiles[a].KaijuRolled and Kaiju.rollsOwed(profiles[a]) == 0,
		"The roll didn't join you"
	)
	check(noted(a, "Your kaiju: "), "Nobody told them about their kaiju")
	check(#registered.KaijuRoll(a).Rolls == 0 and registered.KaijuRollClaim(a).Added == 0, "A second roll")
	KaijuServer._upkeep(a, now)
	local team = KaijuServer.team(a)
	check(#team == 3, "Not three out: " .. #team)
	for slot, member in team do
		check(member.Slot == slot and member.Model:GetAttribute("KaijuSlot") == slot, "The team's places are wrong")
		check((member.Root.Position - rootA.Position).Magnitude < 12, "One came out far from its owner")
	end
	check(#KaijuServer.all() == 3 and KaijuServer.pets()[a] == team[1], "all() or the lead is wrong")
end
local starter = Kaiju.active(roster)
check(starter.Level == 1 and Kaiju.isSoul(starter.Soul) and starter.Soul.Element == starter.Element, "A bad starter")
check(roster.Active == starter.Id and Kaiju.teamIds(roster)[1] == starter.Id, "The lead isn't the team's first")
-- (The checks below follow one kaiju out: one slot, till "Your team" at the end.)
Kaiju.SlotLevels = { 1 }
KaijuServer._upkeep(a, now)
check(#KaijuServer.team(a) == 1, "One slot, more than one out")
local pet = KaijuServer.pets()[a]
check(pet and pet.Model.Parent == kaijuFolder, "The kaiju isn't out")
check(pet.Model:GetAttribute("KaijuOwner") == 1 and pet.Model:GetAttribute("KaijuLevel") == 1, "Its attributes")
check(pet.Record == starter, "The lead isn't the one out")
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
local function healthAndInfusing()
	-- Its health is kept: hurt, it stays hurt, in the fight and out of it,
	-- away and back out (no healing on its own).
	pet.Humanoid.Health = pet.Humanoid.MaxHealth
	KaijuServer.hurt(pet, 60, nil, nil)
	local hurtTo = pet.Humanoid.Health
	check(hurtTo < pet.Humanoid.MaxHealth and pet.Record.Health == hurtTo, "Its health wasn't kept on its record")
	pet.LastFight = now - 60
	for _ = 1, 40 do
		KaijuServer._think(pet, now, 0.5)
	end
	check(pet.Humanoid.Health == hurtTo, "It healed on its own")
	a:SetAttribute("Outpost", nil)
	KaijuServer._upkeep(a, now)
	check(KaijuServer.pets()[a] == nil and starter.Health == hurtTo, "Put away, its health wasn't kept")
	a:SetAttribute("Outpost", true)
	KaijuServer._upkeep(a, now + 600)
	pet = KaijuServer.pets()[a]
	check(pet and pet.Humanoid.Health == hurtTo, "Out again, it came back healed")
	-- Knocked out at 0: back in its Gemsoul, down, till its revive time is
	-- up (by level, on the wall clock: it counts while you're away). Gems
	-- don't bring it back.
	table.clear(notes)
	KaijuServer.hurt(pet, 1e6, nil, nil)
	check(KaijuServer.pets()[a] == nil and pet.Model.Parent == nil, "Not knocked out at 0")
	check(starter.Down == true and starter.Health == 0, "Its record doesn't say it's down")
	local wait = Kaiju.reviveSeconds(starter)
	check(starter.DownUntil == 1700000000 + math.floor(now) + wait, "Its revive time isn't kept on its record")
	check(noted(a, "knocked out") and noted(a, "back by itself"), "Not told it was knocked out, and when it's back")
	check(Kaiju.inTeam(roster, starter.Id), "Down, it lost its place in the team")
	local function stone(id, tier, element)
		local gem = { Id = id, Tier = tier, Element = element, Size = 5, Clarity = 5, Cut = 5 }
		table.insert(profiles[a].Gems, gem)
		return gem
	end
	local record = starter
	local weakness = shared("ElementMatchup").weakTo(record.Element)
	local other = "Fire"
	for _, element in Kaiju.Elements do
		if element ~= record.Element and element ~= weakness then
			other = element
		end
	end
	stone("own", "Common", record.Element)
	check(not registered.KaijuInfuse(a, { "own" }, record.Id).Ok and record.Down, "Gems brought it back")
	check(#profiles[a].Gems == 1, "A refused heal ate a gem")
	now += wait - 5
	KaijuServer._upkeep(a, now)
	check(KaijuServer.pets()[a] == nil and record.Down, "Back before its revive time")
	now += 6
	table.clear(notes)
	local levelBefore, expBefore = record.Level, record.Exp
	KaijuServer._upkeep(a, now)
	pet = KaijuServer.pets()[a]
	local _, starterMost = Kaiju.health(record)
	check(not record.Down and record.DownUntil == nil, "Not back once its revive time was up")
	check(record.Health == math.floor(starterMost * Kaiju.Revive.Health + 0.5), "Not back weak, at Revive.Health")
	check(Kaiju.Revive.Health <= 0.2, "Back by itself, it isn't weak enough to need healing")
	check(pet and pet.Record == record and pet.Humanoid.Health == record.Health, "Back, it didn't come out as it was")
	check(noted(a, "back on its feet") and record.Level == levelBefore and record.Exp == expBefore, "Not told it's back, or given EXP")
	-- Robux or a Revive coupon (reviveAll): every one that's down, back now.
	KaijuServer.hurt(pet, 1e6, nil, nil)
	check(record.Down, "Not knocked out again")
	check(KaijuServer.reviveAll(a) == 1 and not record.Down, "reviveAll didn't bring it back")
	check(
		record.Health == math.floor(starterMost * Kaiju.Revive.Bought + 0.5),
		"Bought back, it isn't at Revive.Bought"
	)
	check(Kaiju.Revive.Bought > Kaiju.Revive.Health, "Buying it back isn't better than waiting")
	pet = KaijuServer.pets()[a]
	check(pet and pet.Record == record, "Revived, it didn't come out")
	check(KaijuServer.reviveAll(a) == 0, "reviveAll counted one that wasn't down")
	for _, gem in table.clone(profiles[a].Gems) do
		PlayerData.removeGem(a, gem.Id)
	end
	-- Up and hurt: stones mend it, only as many as it needs.
	for _, gem in table.clone(profiles[a].Gems) do
		PlayerData.removeGem(a, gem.Id)
	end
	pet.Humanoid.Health = pet.Humanoid.MaxHealth * 0.8
	local mendIds = {}
	for i = 1, 5 do
		stone("m" .. i, "Common", other)
		table.insert(mendIds, "m" .. i)
	end
	local mended = registered.KaijuInfuse(a, mendIds, record.Id)
	check(
		mended.Ok and not mended.Revived and mended.Used == 2,
		"Mending 20% didn't take two commons: " .. tostring(mended.Used)
	)
	check(pet.Humanoid.Health == pet.Humanoid.MaxHealth and record.Health == pet.Humanoid.MaxHealth, "Not mended whole")
	check(#profiles[a].Gems == 3, "Stones it didn't need were eaten")
	check(not registered.KaijuInfuse(a, { "m3" }, record.Id).Ok, "Infused one already whole")
	-- Only out of danger: not while one of the team out has just fought.
	pet.Humanoid.Health = math.floor(pet.Humanoid.MaxHealth * 0.5)
	pet.LastFight = now - 1
	check(KaijuServer.inDanger(a, now), "A fight just now isn't danger")
	local blocked = registered.KaijuInfuse(a, { "m3" }, record.Id)
	check(not blocked.Ok and blocked.Danger and #profiles[a].Gems == 3, "Healed in the middle of a fight")
	pet.LastFight = now - Kaiju.Danger.Calm - 0.1
	check(not KaijuServer.inDanger(a, now), "Still in danger once it's calm")
	check(registered.KaijuInfuse(a, { "m3" }, record.Id).Ok, "Couldn't heal out of danger")
	pet.Humanoid.Health = pet.Humanoid.MaxHealth
	pet.Humanoid.Health = 1
	check(not registered.KaijuInfuse(a, { "nope" }).Ok, "Infused stones they don't have")
	check(not registered.KaijuInfuse(a, {}).Ok and not registered.KaijuInfuse(a, "m3").Ok, "Infused nothing")
	local many = {}
	for i = 1, Kaiju.Infuse.Batch + 1 do
		many[i] = "x" .. i
	end
	check(not registered.KaijuInfuse(a, many).Ok, "Infused more than the limit at once")
	check(not registered.KaijuInfuse(b, { "m3" }).Ok, "Infused with no kaiju")
	table.insert(
		profiles[a].Gems,
		Kaiju.rollSoul(Random.new(9), record.Element, { Id = "soulgem", Time = 1, Species = "Bulwark" })
	)
	check(not registered.KaijuInfuse(a, { "soulgem" }, record.Id).Ok, "A Gemsoul was infused")
	-- (A stone on your gear stays there.)
	local worn = stone("worn", "Rare", record.Element)
	profiles[a].Character = { WeaponGem = worn }
	check(not registered.KaijuInfuse(a, { "worn" }, record.Id).Ok, "A stone on your gear was infused")
	profiles[a].Character = nil
	for _, gem in table.clone(profiles[a].Gems) do
		PlayerData.removeGem(a, gem.Id)
	end
	pet.Humanoid.Health = pet.Humanoid.MaxHealth
end
healthAndInfusing()

-- Auto heal: off till it's switched on; then spare Commons heal the team by
-- themselves, out of danger (never a gem wasted, never a rarer one, never
-- one a saved loadout names), never a revive; quiet, but once for running
-- out.
local function autoHealing()
	local roster = profiles[a].Kaiju
	local record = pet.Record
	local weakness = shared("ElementMatchup").weakTo(record.Element)
	local plain = "Fire"
	for _, element in Kaiju.Elements do
		if element ~= record.Element and element ~= weakness then
			plain = element
		end
	end
	local function gem(id, tier)
		table.insert(profiles[a].Gems, { Id = id, Tier = tier, Element = plain, Size = 5, Clarity = 5, Cut = 5 })
	end
	local function has(id)
		for _, g in profiles[a].Gems do
			if g.Id == id then
				return true
			end
		end
		return false
	end
	local function said(text)
		local count = 0
		for _, note in notes do
			if note[1] == a and string.find(note[2], text, 1, true) then
				count += 1
			end
		end
		return count
	end
	check(registered.KaijuAutoHeal ~= nil, "KaijuAutoHeal isn't a request")
	check(not Kaiju.autoHealOn(roster), "Auto heal on before it was switched on")
	for i = 1, 6 do
		gem("ah" .. i, "Common")
	end
	gem("rare", "Rare")
	local most = pet.Humanoid.MaxHealth
	pet.Humanoid.Health = math.floor(most * 0.65)
	pet.LastFight = now - 60
	KaijuServer._autoHeal(a, now)
	check(#profiles[a].Gems == 7 and pet.Humanoid.Health < most, "Healed with auto heal off")
	local on = registered.KaijuAutoHeal(a, true)
	check(on.Ok and roster.AutoHeal == true and Kaiju.autoHealOn(roster), "Couldn't switch auto heal on")
	check(not registered.KaijuAutoHeal(a, "yes").Ok and roster.AutoHeal == true, "Auto heal took something not on or off")
	-- Mid-fight: not yet.
	pet.LastFight = now - 1
	KaijuServer._autoHeal(a, now)
	check(#profiles[a].Gems == 7, "Auto healed mid-fight")
	-- Calm: 35% short, a Common mends 10%: three, none wasted, never the Rare.
	pet.LastFight = now - Kaiju.Danger.Calm - 0.1
	local before = pet.Humanoid.Health
	KaijuServer._autoHeal(a, now)
	check(#profiles[a].Gems == 4 and has("rare"), "Auto heal didn't take three Commons alone: " .. #profiles[a].Gems .. " left")
	check(
		math.abs(pet.Humanoid.Health - (before + most * 0.3)) <= 1 and record.Health == pet.Humanoid.Health,
		"Three Commons didn't heal 30%"
	)
	-- Not again straight away.
	pet.Humanoid.Health = math.floor(most * 0.5)
	KaijuServer._autoHeal(a, now + 0.5)
	check(#profiles[a].Gems == 4, "Auto healed again straight away")
	-- A gem a saved loadout names stays put.
	now += Kaiju.AutoHeal.Every + 0.1
	pet.LastFight = now - Kaiju.Danger.Calm - 0.1
	profiles[a].Presets = { Armor = { { Surges = { "ah4" } } } }
	KaijuServer._autoHeal(a, now)
	check(has("ah4") and not has("ah5") and not has("ah6") and has("rare"), "Auto heal took a gem a loadout names")
	-- Out of spare Commons: said once.
	now += Kaiju.AutoHeal.Every + 0.1
	pet.LastFight = now - Kaiju.Danger.Calm - 0.1
	table.clear(notes)
	KaijuServer._autoHeal(a, now)
	KaijuServer._autoHeal(a, now + 5)
	check(said("out of spare Commons") == 1, "Running out of Commons wasn't said once")
	check(has("ah4") and has("rare"), "Out of Commons, it took another gem")
	-- Out of Commons, a spare Uncommon heals (never the Rare).
	gem("un1", "Uncommon")
	now += Kaiju.AutoHeal.Every + 0.1
	pet.LastFight = now - Kaiju.Danger.Calm - 0.1
	before = pet.Humanoid.Health
	KaijuServer._autoHeal(a, now)
	check(not has("un1") and has("ah4") and has("rare"), "Out of Commons, auto heal didn't take the Uncommon")
	check(pet.Humanoid.Health > before, "The Uncommon didn't heal")
	profiles[a].Presets = nil
	for _, g in table.clone(profiles[a].Gems) do
		PlayerData.removeGem(a, g.Id)
	end
	-- Knocked out: auto heal leaves it be (it comes back by itself, or for
	-- Robux or a coupon).
	for i = 1, 30 do
		gem("rv" .. i, "Common")
	end
	now += 10
	KaijuServer.hurt(pet, 1e9, nil, nil)
	KaijuServer._autoHeal(a, now + 30)
	check(record.Down and #profiles[a].Gems == 30, "Auto heal revived one, or spent Commons on it")
	KaijuServer.reviveAll(a)
	pet = KaijuServer.pets()[a]
	-- Off again.
	check(registered.KaijuAutoHeal(a, false).Ok and not Kaiju.autoHealOn(roster), "Couldn't switch auto heal off")
	for _, g in table.clone(profiles[a].Gems) do
		PlayerData.removeGem(a, g.Id)
	end
	pet.Humanoid.Health = pet.Humanoid.MaxHealth
	now += 10
end
autoHealing()

-- Recall.
check(registered.KaijuRecall(a).Ok and pet.RecallUntil == now + Kaiju.RecallSeconds, "Recall didn't take")
check(not registered.KaijuRecall(b).Ok, "Recalled a kaiju they don't have")
check(not KaijuServer.targetable(pet), "A recalled kaiju can be fought")
now += Kaiju.RecallSeconds + 0.1
check(KaijuServer.targetable(pet), "Still recalled")

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
-- (Its prompt shows only while nobody's in a fight with it.)
local challengePrompt = enemy.Root:FindFirstChild("ChallengePrompt")
KaijuWilds._brain(enemy, now)
check(challengePrompt.Enabled, "A calm wild kaiju's Challenge prompt is off")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(40, 0, 0))
check(not Challenge(a, enemy.Model).Ok, "Challenged it from 40 studs")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(3, 0, 0))
check(not Challenge(a, make("Model")).Ok, "Challenged something that isn't a wild kaiju")
check(Challenge(a, enemy.Model).Ok and wild.Engaged[a] ~= nil, "A hunter couldn't challenge it")
check(not challengePrompt.Enabled, "Its Challenge prompt still shows in the fight")
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
-- You walk off mid-fight (to mine): it sees the fight through, past the
-- leash and past where it'd be put back beside you (Kaiju.Follow.Battle).
do
	local fightAt = pet.Root.Position
	rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(Kaiju.Follow.Teleport + 10, 0, 0))
	for _ = 1, 6 do
		now += 0.15
		KaijuServer._think(pet, now, 0.15)
	end
	check(pet.Target == enemy and pet.Fighter.Engaged, "Your kaiju left its fight when you walked off")
	check((pet.Root.Position - fightAt).Magnitude < 20, "It was put back beside you mid-fight")
	-- Too far (Battle studs): it gives up and is put back beside you.
	rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(Kaiju.Follow.Battle + 20, 0, 0))
	KaijuServer._think(pet, now, 0.15)
	check(pet.Target == nil and (pet.Root.Position - rootA.Position).Magnitude < 20, "It fought on with you across the quarry")
	-- Back beside it: on again.
	rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(6, 0, 0))
	pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
	KaijuServer._think(pet, now, 0.15)
	check(pet.Target == enemy, "It didn't take the fight up again")
end
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
check(challengePrompt.Enabled, "Its Challenge prompt didn't come back once it calmed down")
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
do
	local warned = drew("Telegraph")
	check(warned ~= nil, "No warning on the ground for a heavy")
	check(not drew("Nova"), "A heavy's warning went off as a blast too (it lands as a stomp)")
	local warnColor = nil
	for _, value in warned or {} do
		if typeof(value) == "Color3" then
			warnColor = value
		end
	end
	check(
		warnColor == shared("GemConfig").ElementColors[pet.Record.Element],
		"A heavy's warning isn't in its element's colour"
	)
end
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

-- A Razorback (the pet fighting as one): its combo landed up close, it
-- hops back out of reach and looses volleys of spines (each a Shot
-- "Spine", each landing), then closes in for the next combo.
do
	now += 5
	settle(fighter)
	settle(wf)
	local style, phase = fighter.Style, fighter.Phase
	fighter.Style = KaijuFight.style("Razorback")
	local ranged = fighter.Style.Ranged
	enemy.GuardUntil, enemy.DodgeUntil, enemy.StunUntil = 0, 0, 0
	pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(fighter.Reach * 0.8, 0, 0))
	pet.Root.AssemblyLinearVelocity = Vector3.zero
	fightRoll = 0.95 -- (no combo goes on)
	table.clear(fxs)
	fighter.Action = { Kind = "Light", At = now, Hits = ranged.Combo }
	KaijuFighter.step(fighter, wildFoe, now)
	check(fighter.Phase == "Range", "Its combo done, a Razorback didn't go out to range")
	check(drew("DodgeRoll") ~= nil and pet.DodgeUntil > now, "It didn't hop back")
	local away = pet.Root.AssemblyLinearVelocity
	check(away:Dot(pet.Root.Position - enemy.Root.Position) > 0, "It hopped toward its foe, not back")
	-- Out at range: a volley, named on its cast bar, then its spines.
	local band = (ranged.Keep[1] + ranged.Keep[2]) / 2 * fighter.Reach / shared("DuelistBrain").Reach
	pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(band + enemy.Root.Size.X / 2, 0, 0))
	now += 0.5
	fightRoll = 0.5
	KaijuFighter.step(fighter, wildFoe, now)
	check(fighter.Action and fighter.Action.Kind == "Volley", "No volley from range: " .. tostring(fighter.Choice))
	check(pet.Model:GetAttribute("ActionName") == ranged.Name, "A volley isn't named")
	check(pet.Model:GetAttribute("ActionKind") == "Bolt", "A volley doesn't wind up as a Bolt")
	table.clear(fxs)
	local hp = enemy.Humanoid.Health
	local shots = 0
	for _ = 1, ranged.Shots + 2 do
		if fighter.Action and fighter.Action.Kind == "Volley" then
			now = fighter.Action.At
			KaijuFighter.step(fighter, wildFoe, now)
			shots += 1
		end
	end
	local spines = 0
	for _, entry in fxs do
		local kind = if entry[1] == "Sized" then entry[3] else entry[1]
		local look = if entry[1] == "Sized" then entry[8] else entry[6]
		if kind == "Shot" and look == "Spine" then
			spines += 1
		end
	end
	check(shots == ranged.Shots and spines == ranged.Shots, "A volley isn't its spines: " .. shots .. "/" .. spines)
	check(enemy.Humanoid.Health < hp, "Its spines didn't land")
	check(fighter.VolleysLeft == ranged.Volleys - 1 and fighter.Phase == "Range", "One volley ended its shooting")
	-- Its last volley shot: it closes in again.
	fighter.VolleysLeft = 1
	fighter.NextVolley = 0
	now += 0.2
	KaijuFighter.step(fighter, wildFoe, now)
	for _ = 1, ranged.Shots + 2 do
		if fighter.Action and fighter.Action.Kind == "Volley" then
			now = fighter.Action.At
			KaijuFighter.step(fighter, wildFoe, now)
		end
	end
	check(fighter.Phase == "Melee", "After its last volley, it didn't go back in")
	-- Pressed close out at range, it hops back again.
	fighter.Phase, fighter.NextHop, fighter.NextVolley = "Range", 0, now + 5
	pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(fighter.Reach * 0.5, 0, 0))
	pet.DodgeUntil = 0
	now += 0.3
	KaijuFighter.step(fighter, wildFoe, now)
	check(fighter.Choice == "Hop" and pet.DodgeUntil > now, "Pressed close, it didn't hop back")
	-- Out of the fight, its next one opens up close.
	KaijuFighter.calm(fighter)
	check(fighter.Phase == nil, "Calm, it was still out at range")
	fighter.Style, fighter.Phase = style, phase
	fightRoll = nil
	settle(fighter)
	settle(wf)
end

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
check(not enemy.Root:FindFirstChild("ChallengePrompt").Enabled, "Its Challenge prompt shows while it's being tamed")
local heldHealth = enemy.Humanoid.Health
Enemies.damage(enemy, 500, b, false, nil, nil, nil)
check(enemy.Alive and enemy.Humanoid.Health == heldHealth, "A held kaiju was hurt")
check(Tame(a, enemy.Model).Message:find("catching") ~= nil, "Cast twice on one")
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
-- (A bite winds up first: the body shows it coming. Crocodilo lobs a bomb
-- instead, which lands a moment later.)
local lob = Kaiju.BugMoves[entry.Species] and Kaiju.BugMoves[entry.Species].Lob
check(
	#playerHits == 0 and bug.Model:GetAttribute("ActionKind") == (if lob then "Bolt" else "Slash"),
	"It bit without a wind-up"
)
now += if lob then lob.Windup else Kaiju.Bug.BiteWindup
KaijuWilds._brain(bug, now)
if lob then
	now += lob.Flight
	KaijuWilds._brain(bug, now)
end
check(#playerHits > 0 and playerHits[#playerHits][1] == b and not playerHits[#playerHits][5], "It never bit them")
-- More come, but never more than the fringe's cap round one player,
-- counting those still on their way through.
for _ = 1, 160 do
	swingFor(1, 0.4)
	local coming = #critterFor(b) + (FrontierServer._pending[b] or 0)
	local allowed = Frontier.capFor("Fringe", FrontierServer._states[b].Stir)
	check(coming <= allowed, "More critters than the fringe allows")
end
check(#critterFor(b) >= 2, "Rifts stopped opening round a miner out in the fringe")
-- Standing about out there, not mining: hardly any (a trickle every few
-- minutes: one swarm at most). (The swarms still hopping out first.)
now += Frontier.Rift.Hop + Frontier.Swarm.Last + 3
runDelayed()
clearCritters()
for _ = 1, 40 do
	now += 0.5
	FrontierServer._step(0.5)
	runDelayed()
end
check(#critterFor(b) <= Frontier.incursion("Fringe", 0.99), "Standing still drew critters like mining")

-- Out at the edge: tougher critters, from level 9 (on a calm frontier:
-- stirred up, they come higher still, below).
clearCritters()
FrontierServer._states[b].Stir = 0
stand(center + Vector3.new(360, 5, 0))
local edgeBug, edgeStir
swingFor(200, 0.4, function()
	for _, enemy in critterFor(b) do
		if KaijuWilds._wilds[enemy].Band == "Edge" then
			edgeBug = enemy
			edgeStir = FrontierServer._states[b].Stir
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
local stirred = math.floor(Frontier.Disturbance.Levels * (edgeStir or 0))
check(edgeLevel >= 9 and edgeLevel <= 13 + stirred, "An edge critter's level: " .. tostring(edgeLevel))
check(edgeBug.Humanoid.MaxHealth > bug.Humanoid.MaxHealth, "An edge critter isn't tougher")
check(#critterFor(b) <= Frontier.capFor("Edge", FrontierServer._states[b].Stir), "More critters than the edge allows")

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

-- Stirring it up -------------------------------------------------------------------------------------------
-- The longer a miner keeps at it out there, the harder the frontier pushes
-- back: their swings stir it up (FrontierStir, for the HUD), and stirred up
-- an encounter brings more critters, higher-levelled, with more allowed
-- about them. It holds while they keep mining, settles once they stop, and
-- faster back in the core.
local function stirringUp()
	local D = Frontier.Disturbance
	local state = FrontierServer._states[b]
	local function shownStir()
		return math.floor(state.Stir * 20 + 0.5) / 20
	end
	local function idle(seconds: number)
		for _ = 1, seconds * 2 do
			now += 0.5
			FrontierServer._step(0.5)
		end
	end
	clearCritters()
	state.Stir, state.Noise = 0, 0
	stand(center + Vector3.new(360, 5, 0))
	swingFor(25, 0.4)
	check(math.abs(state.Stir - 25 * D.PerSwing.Edge) < 1e-6, "Swings at the edge didn't stir it up: " .. state.Stir)
	check(b:GetAttribute("FrontierStir") == shownStir(), "The HUD isn't told how stirred up it is")
	-- Told as it gets restless, once (not again every swing).
	table.clear(notes)
	state.Stir = D.Stages[2].At - D.PerSwing.Edge / 2
	swingFor(3, 0.4)
	local told = 0
	for _, note in notes do
		if note[1] == b and note[2] == D.Notes[2] then
			told += 1
		end
	end
	check(told == 1, "Not told once that the frontier is restless: " .. told)
	-- A pause between rocks doesn't settle it.
	clearCritters()
	local held = state.Stir
	state.Noise = 0
	idle(D.Rest / 2)
	check(state.Stir == held, "A pause between rocks settled it")

	-- Swarming: an encounter brings its stage's more, higher-levelled, past
	-- the calm edge's cap. (Any swarm still trickling in from before comes
	-- through first.)
	local drainUntil = now
		+ Frontier.Swarm.Every[2] * Frontier.capFor("Edge", 1)
		+ Frontier.Rift.Hop
		+ Frontier.Swarm.Last
	while now < drainUntil do
		now += 0.1
		runDelayed()
	end
	clearCritters()
	check(FrontierServer._pending[b] == nil, "A swarm still on its way after it all came through")
	state.Stir, state.Noise, state.LastEncounter = 1, 1, -math.huge
	now += 0.4
	local swungAt = now
	FrontierServer.swing(b)
	local coming = FrontierServer._pending[b] or 0
	check(coming > Frontier.Caps.Edge, "Swarming, an encounter brought no more critters: " .. coming)
	check(coming <= Frontier.capFor("Edge", 1), "Swarming, past its cap: " .. coming)
	-- It trickles in: a tear of its own for each, one after another, a
	-- second or more apart, each well clear of those still open; never a
	-- crowd hopping out at once.
	local tears, seen, mostAtOnce = {}, {}, 0
	local swarmEnd = now + Frontier.Swarm.Every[2] * coming + Frontier.Rift.Hop + Frontier.Swarm.Last + 0.5
	while now < swarmEnd do
		runDelayed()
		local open = {}
		for _, rift in rifts() do
			if rift:GetAttribute("Prey") == b.UserId then
				table.insert(open, rift)
				if not seen[rift] and rift:GetAttribute("OpenAt") >= swungAt - 0.01 then
					seen[rift] = true
					table.insert(tears, rift)
				end
			end
		end
		for i = 1, #open do
			for j = i + 1, #open do
				local gap = open[i].Position - open[j].Position
				check(
					Vector3.new(gap.X, 0, gap.Z).Magnitude >= Frontier.Rift.Apart - 0.5,
					"Two of a swarm's tears too close together"
				)
			end
		end
		mostAtOnce = math.max(mostAtOnce, #open)
		now += 0.1
	end
	runDelayed()
	check(#tears == coming, "Not a tear for each swarming critter: " .. #tears .. " for " .. coming)
	check(mostAtOnce <= 4, "Too many of a swarm's tears open at once: " .. mostAtOnce)
	table.sort(tears, function(x, y)
		return x:GetAttribute("OpenAt") < y:GetAttribute("OpenAt")
	end)
	for i = 2, #tears do
		local gap = tears[i]:GetAttribute("OpenAt") - tears[i - 1]:GetAttribute("OpenAt")
		check(gap >= Frontier.Swarm.Every[1] - 0.15, "A swarm's tears opened at once: " .. gap)
	end
	local list = critterFor(b)
	check(#list == coming, "Not every swarming critter came through: " .. #list .. " of " .. coming)
	for _, enemy in list do
		local level = KaijuWilds._wilds[enemy].Level
		check(level >= 9 + D.Levels and level <= 13 + D.Levels, "A swarming edge critter's level: " .. level)
	end
	-- Calm again, the edge's own cap and levels (above).

	-- They stop: past the rest it settles, a little each second, and the HUD
	-- follows.
	clearCritters()
	state.Stir, state.Noise, state.LastSwing = 0.6, 0, now
	idle(D.Rest)
	check(state.Stir == 0.6, "It settled before the rest was up")
	idle(10)
	check(math.abs(state.Stir - (0.6 - 10 * D.Fade)) < 1e-6, "It didn't settle once they stopped: " .. state.Stir)
	check(b:GetAttribute("FrontierStir") == shownStir(), "The HUD wasn't told it settled")
	-- Back in the core it settles faster, swinging or not (and swinging
	-- there stirs nothing).
	stand(center + Vector3.new(40, 5, 0))
	local was = state.Stir
	swingFor(10, 0.5)
	check(math.abs(state.Stir - (was - 5 * D.CoreFade)) < 1e-6, "The core didn't settle it: " .. state.Stir)
	idle(1 / D.CoreFade)
	check(state.Stir == 0 and b:GetAttribute("FrontierStir") == 0, "The core never calmed it")
	clearCritters()
	runDelayed()
end
stirringUp()

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
-- One climbs out at a time (Swarm.Out apart), not the lot at once.
check(#critterFor(b) == 1, "A wandering rift's critters came out all at once: " .. #critterFor(b))
while (FrontierServer._pending[b] or 0) > 0 and now < wanderRift:GetAttribute("CloseAt") do
	now += 0.1
	runDelayed()
end
check(
	FrontierServer._pending[b] == nil and now <= wanderRift:GetAttribute("CloseAt"),
	"The tear sealed before they were all out"
)
local roamers = critterFor(b)
check(#roamers >= 2 and KaijuWilds._wilds[roamers[1]].Wander ~= nil, "No critters roamed out of the wandering rift")
-- (A fighter: a ranged one jets off from a player walking up, as it should.)
local roamer = roamers[1]
for _, critter in roamers do
	if not Kaiju.isRanged(KaijuWilds._wilds[critter].Species) then
		roamer = critter
		break
	end
end
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
	enemy.DodgeUntil = 0 -- (not mid-hop)
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
-- (One that bites: Crocodilo lobs bombs from range instead; its own move and
-- its dodges held back.)
local biter = KaijuWilds.spawnBug(center + Vector3.new(330, 0, 0), { Band = "Fringe", Critter = "Sahur" })
KaijuWilds._wilds[biter].Prey = nil
biter.NextMove, biter.NextDodge = math.huge, math.huge
pet = KaijuServer.pets()[a]
biter.Root.CFrame = CFrame.new(pet.Root.Position + Vector3.new(1.5, 0, 0))
biter.Home, biter.LastAttack, pet.RecallUntil = biter.Root.Position, 0, 0
settle(pet.Fighter)
local health = pet.Humanoid.Health
KaijuWilds._brain(biter, now) -- (it winds up its bite...)
now += Kaiju.Bug.BiteWindup
KaijuFight.raiseGuard(pet.Fighter, now, 2) -- (...and the guard goes up just as it lands)
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
	-- (At home: one whose den just moved on heads straight there instead.)
	we.Root.CFrame = CFrame.new(we.Home)
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
	-- (Its own move held back: a spore burst or a slam reaches you beside
	-- your kaiju, by rights; this is about its bites.)
	critter.NextMove = math.huge
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
	-- A long session's rocks are worth a couple of early levels, no more
	-- (levelling is slow: Kaiju.ExpCurve).
	local session = { Level = 1, Exp = 0 }
	for i = 1, 130 do
		Kaiju.addExp(session, Kaiju.mineExp(if i % 8 < 3 then "Boulder" else "Pebble"))
	end
	check(session.Level >= 2 and session.Level <= 3, "A long session's mining made level " .. session.Level)
end
minedWithIt()

-- Your team --------------------------------------------------------------------------------------------------
-- Three slots again: three out at once, each in its place; one knocked out
-- leaves the others out; recall brings them all; EXP for each; a team set
-- and led as you like (only your own, not in a rush, not mid-fight); any of
-- yours fed; and a roll left unclaimed given after a while in the Outpost.
local function yourTeam()
	Kaiju.SlotLevels = { 1, 1, 1 }
	for _, key in { "CombatSession", "MatchId", "DungeonId", "Expedition", "Hunt", "Spar" } do
		a:SetAttribute(key, nil)
	end
	a:SetAttribute("Outpost", true)
	now += 10
	KaijuServer._upkeep(a, now)
	local squad = KaijuServer.team(a)
	check(#squad == 3, "Three slots, not three out: " .. #squad)
	local squadIds = Kaiju.teamIds(roster)
	for slot, member in squad do
		check(member.Slot == slot and member.Record.Id == squadIds[slot], "The team out isn't the team")
	end
	-- One knocked out: the others stay out; it keeps its place, down,
	-- till it's revived; then it's back in its place.
	local downed = squad[2]
	KaijuServer.hurt(downed, 1e9, nil, nil)
	KaijuServer._upkeep(a, now)
	local left = KaijuServer.team(a)
	check(#left == 2 and not table.find(left, downed), "A knockout took the others away")
	check(downed.Record.Down and Kaiju.teamIds(roster)[2] == downed.Record.Id, "Down, it lost its place")
	now += 5
	KaijuServer._upkeep(a, now)
	check(#KaijuServer.team(a) == 2, "It came back before its revive time")
	check(KaijuServer.reviveAll(a) == 1, "Couldn't revive one of the team")
	squad = KaijuServer.team(a)
	check(#squad == 3 and squad[2].Record == downed.Record, "Revived, it didn't come back to its place")
	for _, gem in table.clone(profiles[a].Gems) do
		PlayerData.removeGem(a, gem.Id)
	end
	-- Recall: all of them.
	check(registered.KaijuRecall(a).Ok, "No recall")
	for _, member in squad do
		check(member.RecallUntil == now + Kaiju.RecallSeconds, "Recall missed one of the team")
	end
	now += Kaiju.RecallSeconds + 0.1
	-- Call back: the whole team away in its Gemsouls, none of it out (and
	-- kept away through upkeep); deploying waits till you're out of
	-- danger, then they're all back.
	local inDanger = KaijuServer.inDanger
	check(registered.KaijuCallBack(a, true).Ok, "Couldn't call the team back")
	check(Kaiju.away(roster) and #KaijuServer.team(a) == 0, "Called back, the team's still out")
	KaijuServer._upkeep(a, now)
	check(#KaijuServer.team(a) == 0, "Upkeep put a called-back team out again")
	KaijuServer.inDanger = function()
		return true
	end
	check(not registered.KaijuCallBack(a, false).Ok and Kaiju.away(roster), "Deployed in danger")
	KaijuServer.inDanger = function()
		return false
	end
	check(registered.KaijuCallBack(a, false).Ok and not Kaiju.away(roster), "Couldn't deploy out of danger")
	KaijuServer.inDanger = inDanger
	squad = KaijuServer.team(a)
	check(#squad == 3, "Deployed, the team isn't all out: " .. #squad)
	check(not registered.KaijuCallBack(a, "yes").Ok, "Called back with nonsense")
	-- EXP: each one out gets it.
	local before = {}
	for _, member in squad do
		before[member] = member.Record.Level * 100000 + (member.Record.Exp or 0)
	end
	KaijuServer.reward(a, 15)
	for _, member in squad do
		check(member.Record.Level * 100000 + (member.Record.Exp or 0) > before[member], "A kaiju out got no EXP")
	end
	-- The team as you set it: the first leads.
	local order = { squadIds[3], squadIds[1], squadIds[2] }
	now += 5
	check(registered.KaijuTeam(a, order).Ok, "Couldn't set the team")
	check(KaijuServer.team(a)[1].Record.Id == squadIds[3] and roster.Active == squadIds[3], "The new lead isn't first")
	check(not registered.KaijuTeam(a, squadIds).Ok, "Changed the team twice in a moment")
	now += 5
	check(not registered.KaijuTeam(a, { "nope" }).Ok, "Put out a kaiju they don't own")
	check(not registered.KaijuTeam(a, { order[1], order[1] }).Ok, "Put the same kaiju out twice")
	check(not registered.KaijuTeam(a, { order[1], order[2], order[3], order[1] }).Ok, "Four out")
	local bench
	for id in roster.List do
		if not table.find(Kaiju.teamIds(roster), id) then
			bench = id
		end
	end
	check(bench ~= nil, "No kaiju left at home to test with")
	-- Swapping one mid-fight out: refused; once it's calm, done.
	KaijuServer.team(a)[3].LastFight = now
	check(not registered.KaijuTeam(a, { order[1], order[2], bench }).Ok, "Swapped one out mid-fight")
	KaijuServer.team(a)[3].LastFight = now - 10
	check(registered.KaijuTeam(a, { order[1], order[2], bench }).Ok, "Couldn't swap one in from home")
	check(Kaiju.teamIds(roster)[3] == bench and #KaijuServer.team(a) == 3, "The one from home didn't come out")
	-- KaijuActive: one from home into the lead's place.
	now += 5
	local home = order[3]
	check(registered.KaijuActive(a, home).Ok, "Couldn't lead with one from home")
	check(Kaiju.teamIds(roster)[1] == home and not Kaiju.inTeam(roster, order[1]), "It didn't take the lead's place")
	-- Infusing any of yours: one at home too (its kept health mended).
	local resting
	for id in roster.List do
		if not Kaiju.inTeam(roster, id) then
			resting = roster.List[id]
		end
	end
	local _, restingMost = Kaiju.health(resting)
	resting.Health = math.floor(restingMost / 2)
	table.insert(
		profiles[a].Gems,
		{ Id = "t1", Tier = "Rare", Element = resting.Element, Size = 5, Clarity = 5, Cut = 5 }
	)
	check(registered.KaijuInfuse(a, { "t1" }, resting.Id).Ok, "Couldn't infuse one at home")
	check(resting.Health > math.floor(restingMost / 2), "The one at home wasn't mended")
	check(not registered.KaijuInfuse(a, { "t1" }, "nope").Ok, "Infused a kaiju they don't own")
	-- A roll left unclaimed: given after a while in the Outpost.
	table.clear(notes)
	b:SetAttribute("Outpost", true)
	KaijuServer._upkeep(b, now)
	check(Kaiju.count(profiles[b].Kaiju) == 0 and Kaiju.rollsOwed(profiles[b]) == 3, "Given the roll at once")
	KaijuServer._upkeep(b, now + Kaiju.RollGrace + 1)
	check(Kaiju.count(profiles[b].Kaiju) == 3 and profiles[b].KaijuRolled, "An unclaimed roll was never given")
	check(noted(b, "Your kaiju: "), "Not told about the kaiju given")
	-- Always three: one who took an older roll (a short top-up, left saved
	-- unclaimed here) gets a full new roll of three, once, and the three
	-- rolled become the team.
	local old = profiles[b]
	old.KaijuRolled = true
	old.KaijuRoll =
		{ Rolls = { { Species = "Bulwark", Element = "Fire" }, { Species = "Carapace", Element = "Frost" } } }
	local fresh = KaijuServer._prepareRoll(old)
	check(
		fresh and #fresh.Rolls == Kaiju.StarterTeam and fresh.Version == Kaiju.RollVersion,
		"An older roll wasn't made again as three"
	)
	local claimed = KaijuServer._claimRoll(b)
	check(#claimed == 3 and Kaiju.count(old.Kaiju) == 6, "The full roll didn't join them")
	local ids = Kaiju.teamIds(old.Kaiju)
	for i, record in claimed do
		check(ids[i] == record.Id, "The kaiju rolled aren't the team")
	end
	check(old.KaijuRolled == Kaiju.RollVersion and Kaiju.rollsOwed(old) == 0, "Owed again after the full roll")
	b:SetAttribute("Outpost", nil)
	KaijuServer._despawn(b)
end
yourTeam()

-- Fighting as a team ----------------------------------------------------------------------------------------
-- The creatures shared out (each its own while there are enough: 3 on 3,
-- 2 on 3 with the third waiting, 3 on 1 all in from three sides, 2 on 10
-- with the critters split five and five); clear of each other; critters in a
-- ring, biting and hopping out, dodging a blow coming, each kind's own move;
-- a pack sharing its foes; and a short fight walked through to see it hold.
local function teamFights()
	Kaiju.SlotLevels = { 1, 1, 1 }
	clearCritters()
	for _, key in { "CombatSession", "MatchId", "DungeonId", "Expedition", "Hunt", "Spar" } do
		a:SetAttribute(key, nil)
	end
	a:SetAttribute("Outpost", true)
	local spot = center + Vector3.new(-320, 5, 60)
	rootA.CFrame = CFrame.new(spot)
	stand(center + Vector3.new(320, 5, 0)) -- (b far off)
	now += 10
	KaijuServer._upkeep(a, now)
	local team = KaijuServer.team(a)
	check(#team == 3, "Not three out for the team fights")

	-- You jump, they jump: one after another in team order, a beat apart (and
	-- not again while you're still going up); one fighting stays at it.
	;(function()
		local team = KaijuServer.team(a)
		check(#team >= 2, "Not a team to jump after you")
		for _, p in team do
			p.Target, p.StunUntil, p.HopAt, p.HoppedAt = nil, 0, nil, nil
			p.Humanoid.Jump = false
		end
		local t = now
		rootA.AssemblyLinearVelocity = Vector3.zero
		KaijuServer._hops(a, t)
		rootA.AssemblyLinearVelocity = Vector3.new(4, 50, 0)
		local jumpedAt = {}
		for frame = 1, 90 do
			t += 1 / 60
			if frame > 20 then
				rootA.AssemblyLinearVelocity = Vector3.new(4, 30 - frame, 0) -- (still in the air, coming down)
			end
			KaijuServer._hops(a, t)
			for _, p in team do
				if p.Humanoid.Jump then
					check(jumpedAt[p] == nil, "A kaiju jumped twice for one jump of yours")
					jumpedAt[p] = t - now
					p.Humanoid.Jump = false
				end
			end
		end
		for i, p in team do
			check(jumpedAt[p] ~= nil, "Your kaiju in slot " .. p.Slot .. " didn't jump after you")
			if i > 1 then
				local gap = jumpedAt[p] - jumpedAt[team[i - 1]]
				check(gap > Kaiju.Hop.Stagger * 0.8, "Your kaiju jumped all at once, not one after another: " .. gap)
			end
		end
		check(jumpedAt[team[1]] >= Kaiju.Hop.First * 0.8, "Your kaiju jumped before you did")
		-- Landed and jumping again: so do they; one in a fight doesn't.
		rootA.AssemblyLinearVelocity = Vector3.zero
		KaijuServer._hops(a, t)
		team[1].Target = { Root = team[1].Root }
		rootA.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
		for _ = 1, 60 do
			t += 1 / 60
			KaijuServer._hops(a, t)
		end
		check(not team[1].Humanoid.Jump, "Your kaiju jumped out of its fight")
		check(team[2].Humanoid.Jump, "Your kaiju didn't jump after you the second time")
		for _, p in team do
			p.Target, p.HopAt = nil, nil
			p.Humanoid.Jump = false
		end
		rootA.AssemblyLinearVelocity = Vector3.zero
		check(Kaiju.leapt(nil, 50) and not Kaiju.leapt(40, 50) and not Kaiju.leapt(0, 5), "Kaiju.leapt")
	end)()

	local bugs = {}
	local function reset()
		clearCritters()
		table.clear(bugs)
		for i, pet in team do
			pet.RecallUntil, pet.StunUntil, pet.Plan, pet.IdleSpot, pet.Target = 0, 0, nil, nil, nil
			pet.Humanoid.MaxHealth, pet.Humanoid.Health = 1e6, 1e6
			settle(pet.Fighter)
			pet.Fighter.Flank, pet.Fighter.Apart = nil, nil
			pet.Root.CFrame = CFrame.new(spot + Vector3.new((i - 2) * 6, 0, 3))
		end
	end
	local function bugAt(p: Vector3, species: string?)
		local bug = KaijuWilds.spawnBug(p, { Prey = a, Band = "Fringe", Level = 1, Critter = species })
		bug.Root.CFrame = CFrame.new(p)
		bug.Root.AssemblyLinearVelocity = Vector3.zero
		bug.Home = p
		bug.Humanoid.MaxHealth, bug.Humanoid.Health = 1e6, 1e6
		bug.LastAttack = now
		table.insert(bugs, bug)
		return bug
	end
	local function tick(fighters)
		for _, pet in fighters do
			KaijuServer._think(pet, now, 0.15)
		end
		for _, bug in bugs do
			if bug.Alive then
				KaijuWilds._brain(bug, now)
			end
		end
	end
	local function distinct(fighters): boolean
		local seen = {}
		for _, pet in fighters do
			if not pet.Target or seen[pet.Target] then
				return false
			end
			seen[pet.Target] = true
		end
		return true
	end
	local function onEach(fighters)
		local n = {}
		for _, pet in fighters do
			n[pet] = 0
		end
		for _, bug in bugs do
			if bug.Alive and bug.Foe and n[bug.Foe] then
				n[bug.Foe] += 1
			end
		end
		return n
	end
	-- 3 on 3: one each.
	reset()
	for i = 1, 3 do
		bugAt(spot + Vector3.new((i - 2) * 6, 0, 14))
	end
	tick(team)
	check(distinct(team), "3 on 3: not one each")
	local n = onEach(team)
	check(n[team[1]] == 1 and n[team[2]] == 1 and n[team[3]] == 1, "3 critters on 3 kaiju: not one each")
	-- 3 on 1: all of them, from three sides a third of a turn apart.
	reset()
	local lone = bugAt(spot + Vector3.new(0, 0, 12))
	tick(team)
	tick(team)
	local flanks = {}
	for _, pet in team do
		check(pet.Target == lone, "3 on 1: one stayed out")
		check(pet.Fighter.Flank ~= nil, "3 on 1: one without a side to fight from")
		table.insert(flanks, pet.Fighter.Flank)
	end
	for i = 1, 3 do
		for j = i + 1, 3 do
			check(math.abs(flanks[i]:Dot(flanks[j]) + 0.5) < 1e-3, "3 on 1: not round it a third of a turn apart")
		end
	end
	-- 2 on 3: one each, the third waiting; the critters two and one.
	Kaiju.SlotLevels = { 1, 1 }
	KaijuServer._upkeep(a, now)
	local two = KaijuServer.team(a)
	check(#two == 2, "Two slots, not two out")
	reset()
	for i = 1, 3 do
		bugAt(spot + Vector3.new((i - 2) * 7, 0, 13))
	end
	tick(two)
	check(distinct(two), "2 on 3: not one each")
	n = onEach(two)
	check(n[two[1]] + n[two[2]] == 3 and math.abs(n[two[1]] - n[two[2]]) == 1, "3 critters on 2 kaiju: not two and one")
	-- One falls: the kaiju whose foe it was takes the one left waiting.
	local freed = two[1]
	local fallen = freed.Target
	fallen.Alive = false
	KaijuWilds._wilds[fallen] = nil
	tick(two)
	check(freed.Target ~= nil and freed.Target ~= fallen and distinct(two), "No collapse onto the one left")
	-- 2 on 10: never doubled up, and the critters split five and five.
	reset()
	for i = 1, 10 do
		local turn = i * math.pi * 2 / 10
		bugAt(spot + Vector3.new(math.cos(turn) * 12, 0, 3 + math.sin(turn) * 12))
	end
	tick(two)
	tick(two)
	check(distinct(two), "2 on 10: doubled up")
	n = onEach(two)
	check(n[two[1]] == 5 and n[two[2]] == 5, "10 critters on 2 kaiju: not five each")
	Kaiju.SlotLevels = { 1, 1, 1 }
	KaijuServer._upkeep(a, now)
	team = KaijuServer.team(a)
	-- Clear of each other: two on the same spot get pushed apart.
	reset()
	bugAt(spot + Vector3.new(0, 0, 14))
	team[2].Root.CFrame = team[1].Root.CFrame
	tick(team)
	local push, other = team[1].Fighter.Apart, team[2].Fighter.Apart
	check(push and other and push.Magnitude > 1 and other.Magnitude > 1, "Two kaiju on top of each other stayed put")
	check(push:Dot(other) < 0, "Pushed the same way, not apart")

	-- A critter's bite: a wind-up, then it hops back out and circles.
	reset()
	local pet = team[1]
	local biter = bugAt(pet.Root.Position + Vector3.new(2.5, 0, 0), "Sahur")
	local e = biter :: any
	e.NextMove, biter.LastAttack = math.huge, 0
	KaijuWilds._brain(biter, now)
	check(
		e.Action and e.Action.Kind == "Bite" and biter.Model:GetAttribute("ActionKind") == "Slash",
		"No wind-up to a bite"
	)
	local before = pet.Humanoid.Health
	now += Kaiju.Bug.BiteWindup
	KaijuWilds._brain(biter, now)
	check(biter.Foe == pet and pet.Humanoid.Health < before, "The bite never landed")
	check(biter.Root.AssemblyLinearVelocity:Dot(pet.Root.Position - biter.Root.Position) < 0, "It didn't hop back out")
	check((e.RecoverUntil or 0) > now, "It didn't circle a moment before coming back")
	-- A blow it sees coming: it hops clear, and the blow misses.
	local dodge = Kaiju.Bug.Dodge
	Kaiju.Bug.Dodge = 1
	e.NextDodge, e.RecoverUntil = 0, 0
	pet.Target = biter
	pet.Fighter.Action = { Kind = "Light", At = now + 0.2, Hits = 1 }
	KaijuWilds._brain(biter, now)
	check((biter.DodgeUntil or 0) > now and biter.Model:GetAttribute("ActionKind") == "Dodge", "It never hopped clear")
	check(KaijuServer.strike(pet, biter, 10, nil, false) == "Dodged", "The blow landed through its hop")
	pet.Fighter.Action = nil
	Kaiju.Bug.Dodge = dodge
	-- Each kind's own move, named on its cast bar.
	local function readyMove(species: string, at: Vector3)
		reset()
		local bug = bugAt(at, species)
		local b2 = bug :: any
		b2.NextMove, b2.NextDodge, bug.LastAttack = 0, math.huge, now
		return bug, b2
	end
	local function healthOf()
		local list = {}
		for _, p in team do
			list[p] = p.Humanoid.Health
		end
		return list
	end
	-- Sahur: a slam round its feet; your kaiju read it coming.
	local move = Kaiju.BugMoves.Sahur
	local slammer, sl = readyMove("Sahur", spot + Vector3.new(0, 0, 20))
	team[2].Root.CFrame = CFrame.new(slammer.Root.Position + Vector3.new(0, 0, -3))
	team[1].Root.CFrame = CFrame.new(slammer.Root.Position + Vector3.new(4, 0, 0))
	team[3].Root.CFrame = CFrame.new(slammer.Root.Position + Vector3.new(20, 0, 0))
	KaijuWilds._brain(slammer, now)
	check(sl.Action and slammer.Model:GetAttribute("ActionName") == move.Name, "No Bat Slam on its cast bar")
	check(slammer.Model:GetAttribute("ActionKind") == move.Pose, "The slam isn't posed")
	check(
		KaijuFighter._readFoe(team[2].Fighter, { Root = slammer.Root, Enemy = slammer }, now).Heavy,
		"A kaiju can't see the slam coming"
	)
	local hp = healthOf()
	now += move.Windup
	KaijuWilds._brain(slammer, now)
	check(
		team[1].Humanoid.Health < hp[team[1]] and team[2].Humanoid.Health < hp[team[2]],
		"The slam missed the kaiju inside it"
	)
	check(team[3].Humanoid.Health == hp[team[3]], "The slam reached one far off")
	-- Tralalero: a dash straight through its foe (not one off to the side).
	move = Kaiju.BugMoves.Tralalero
	local dasher = readyMove("Tralalero", spot + Vector3.new(0, 0, 20))
	team[1].Root.CFrame = CFrame.new(dasher.Root.Position + Vector3.new(0, 0, -10))
	team[2].Root.CFrame = CFrame.new(dasher.Root.Position + Vector3.new(9, 0, -10))
	team[3].Root.CFrame = CFrame.new(dasher.Root.Position + Vector3.new(-30, 0, 0))
	KaijuWilds._brain(dasher, now)
	check(
		dasher.Model:GetAttribute("ActionName") == move.Name and dasher.Foe == team[1],
		"No Shark Dash at the one in front"
	)
	hp = healthOf()
	now += move.Windup
	KaijuWilds._brain(dasher, now)
	check(team[1].Humanoid.Health < hp[team[1]], "The dash missed the one it went through")
	check(team[2].Humanoid.Health == hp[team[2]], "The dash hit one off to the side")
	-- Patapim: spores round it, poison left behind.
	move = Kaiju.BugMoves.Patapim
	local burster, bu = readyMove("Patapim", spot + Vector3.new(0, 0, 20))
	team[1].Root.CFrame = CFrame.new(burster.Root.Position + Vector3.new(0, 0, -4))
	team[2].Root.CFrame = CFrame.new(burster.Root.Position + Vector3.new(5, 0, 0))
	team[3].Root.CFrame = CFrame.new(burster.Root.Position + Vector3.new(12, 0, 0))
	KaijuWilds._brain(burster, now)
	check(bu.Action and burster.Model:GetAttribute("ActionName") == move.Name, "No Spore Burst")
	check(
		KaijuFighter._readFoe(team[1].Fighter, { Root = burster.Root, Enemy = burster }, now).Casting,
		"The burst doesn't read as a cast"
	)
	hp = healthOf()
	local dots = #team[2].Dots
	now += move.Windup
	KaijuWilds._brain(burster, now)
	check(
		team[1].Humanoid.Health < hp[team[1]] and team[2].Humanoid.Health < hp[team[2]],
		"The burst missed the kaiju inside it"
	)
	check(
		team[3].Humanoid.Health == hp[team[3]] and #team[2].Dots > dots,
		"The burst reached too far, or left no poison"
	)
	-- Crocodilo: it keeps its distance and lobs bombs where its foe stands;
	-- a kaiju that moves off is missed.
	move = Kaiju.BugMoves.Crocodilo
	local bomber, bo = readyMove("Crocodilo", spot + Vector3.new(0, 0, 25))
	team[1].Root.CFrame = CFrame.new(bomber.Root.Position + Vector3.new(0, 0, -4))
	team[2].Root.CFrame = CFrame.new(spot + Vector3.new(-40, 0, 0))
	team[3].Root.CFrame = CFrame.new(spot + Vector3.new(40, 0, 0))
	bo.NextMove = math.huge
	bomber.LastAttack = now
	KaijuWilds._brain(bomber, now)
	local to = bomber.Humanoid.MovingTo
	check(to and (to - team[1].Root.Position).Magnitude > move.Keep - 1.5, "The bomber didn't keep its distance")
	bomber.LastAttack = now - 10
	KaijuWilds._brain(bomber, now)
	check(bo.Action and bo.Action.Kind == "Lob" and bomber.Model:GetAttribute("ActionKind") == "Bolt", "No lob")
	now += move.Lob.Windup
	KaijuWilds._brain(bomber, now)
	check(bo.Bombs and #bo.Bombs == 1, "No bomb in the air")
	hp = healthOf()
	now += move.Lob.Flight
	KaijuWilds._brain(bomber, now)
	check(team[1].Humanoid.Health < hp[team[1]] and #bo.Bombs == 0, "The bomb didn't land on the one standing there")
	bomber.LastAttack = now - 10
	KaijuWilds._brain(bomber, now)
	now += move.Lob.Windup
	KaijuWilds._brain(bomber, now)
	team[1].Root.CFrame = team[1].Root.CFrame + Vector3.new(8, 0, 0) -- (it moves off)
	hp = healthOf()
	now += move.Lob.Flight
	KaijuWilds._brain(bomber, now)
	check(team[1].Humanoid.Health == hp[team[1]], "A bomb hit a kaiju that moved off")
	-- It only ever fights from range: closed in on, it jets back out (not a
	-- bite), and with its jets spent it still never bites.
	bo.Action, bo.Windup, bo.Bombs, bo.NextFlee = nil, nil, nil, 0
	team[1].Root.CFrame = CFrame.new(bomber.Root.Position + Vector3.new(0, 0, -2))
	bomber.LastAttack = now - 10
	KaijuWilds._brain(bomber, now)
	local jet = bomber.Root.AssemblyLinearVelocity
	check(Vector3.new(jet.X, 0, jet.Z):Dot(Vector3.new(0, 0, 1)) > 20, "Closed in on, the bomber didn't jet back")
	check(bo.Action == nil and bomber.Model:GetAttribute("ActionKind") == "Dodge", "It did something else than jet back")
	check(
		(bomber.Humanoid.MovingTo - team[1].Root.Position).Magnitude > move.Keep - 1,
		"It jetted back but means to stay close"
	)
	for _ = 1, 6 do
		now += 0.3
		team[1].Root.CFrame = CFrame.new(bomber.Root.Position + Vector3.new(0, 0, -2)) -- (kept on it)
		-- (A bite would be ready, its next bomb not yet.)
		bo.Action, bo.Windup = nil, nil
		bomber.LastAttack = now - (Kaiju.Bug.Rate + move.Lob.Every) / 2
		KaijuWilds._brain(bomber, now)
		check(not (bo.Action and bo.Action.Kind == "Bite"), "The bomber bit")
		check(bomber.Model:GetAttribute("ActionKind") ~= "Slash", "The bomber wound up a bite")
	end

	-- Smarter fights ------------------------------------------------------------------------------------
	-- (One kaiju on its own here: the other two well off.)
	local function alone()
		reset()
		table.clear(KaijuWilds._rushes) -- (no pounce left over from the fights above)
		team[2].Root.CFrame = CFrame.new(spot + Vector3.new(200, 0, 0))
		team[3].Root.CFrame = CFrame.new(spot + Vector3.new(-200, 0, 0))
		return team[1]
	end
	-- The swarm pounces together: three fighters on one kaiju, out of breath
	-- or not, all leap in at once, once each, and every bite lands.
	local prey = alone()
	local pack = {}
	for i = 1, 3 do
		local turn = i * math.pi * 2 / 3
		local bug = bugAt(prey.Root.Position + Vector3.new(math.cos(turn) * 5, 0, math.sin(turn) * 5), "Sahur")
		local b3 = bug :: any
		b3.NextMove, b3.NextDodge = math.huge, math.huge
		table.insert(pack, bug)
	end
	for _ = 1, 2 do -- (the first think each picks its foe; then the pounce is set)
		for _, bug in pack do
			KaijuWilds._brain(bug, now)
		end
	end
	local rush = KaijuWilds._rushes[prey.Root]
	check(rush and rush.At > now, "Three on one kaiju and no pounce coming")
	for _, bug in pack do
		check(bug.Foe == prey, "Not all three on the one kaiju")
		local b3 = bug :: any
		b3.Action, b3.RecoverUntil, bug.LastAttack = nil, now + 100, now -- (out of breath)
	end
	now = rush.At + 0.01
	local hp0 = prey.Humanoid.Health
	for _, bug in pack do
		KaijuWilds._brain(bug, now)
		local b3 = bug :: any
		check(b3.Action and b3.Action.Kind == "Bite" and b3.Action.Rush, "One held back from the pounce")
		check(bug.Model:GetAttribute("ActionKind") == "Lunge", "A pounce with no leap")
	end
	now += Kaiju.Bug.BiteWindup
	for _, bug in pack do
		KaijuWilds._brain(bug, now)
	end
	check(prey.Humanoid.Health < hp0, "The pounce never landed")
	for _, bug in pack do
		local b3 = bug :: any
		b3.RecoverUntil, bug.LastAttack = now + 100, now
		KaijuWilds._brain(bug, now + 0.05)
		check(not (b3.Action and b3.Action.Rush), "A critter pounced twice in one pounce")
	end
	-- Hurt, a critter turns wary: it takes longer to come back in.
	prey = alone()
	local hurt = bugAt(prey.Root.Position + Vector3.new(2.5, 0, 0), "Sahur")
	local hb = hurt :: any
	hb.NextMove, hb.NextDodge, hurt.LastAttack = math.huge, math.huge, 0
	hurt.Humanoid.Health = hurt.Humanoid.MaxHealth * (Kaiju.Bug.Skittish / 2)
	KaijuWilds._brain(hurt, now)
	now += Kaiju.Bug.BiteWindup
	KaijuWilds._brain(hurt, now)
	check(
		math.abs((hb.RecoverUntil or 0) - (now + Kaiju.Bug.Recover * Kaiju.Bug.Wary)) < 1e-6,
		"A hurt critter came back in as soon as ever"
	)
	-- On its own on a kaiju facing it, a critter works round toward its back.
	prey = alone()
	local sneak = bugAt(prey.Root.Position + Vector3.new(0, 0, 9), "Sahur")
	local sb = sneak :: any
	sb.NextMove, sb.NextDodge, sneak.LastAttack = math.huge, math.huge, now
	-- (Facing it, along +Z: Lune's CFrame.lookAt gets that one backwards.)
	prey.Root.CFrame = CFrame.new(prey.Root.Position) * CFrame.Angles(0, math.pi, 0)
	KaijuWilds._brain(sneak, now)
	local look = prey.Root.CFrame.LookVector
	local fromNow = (sneak.Root.Position - prey.Root.Position).Unit
	local goingTo = sneak.Humanoid.MovingTo - prey.Root.Position
	goingTo = Vector3.new(goingTo.X, 0, goingTo.Z).Unit
	check(goingTo:Dot(look) < fromNow:Dot(look) - 0.15, "A critter stayed in front of a kaiju facing it")
	-- Your kaiju dive a swarm's bomber, and finish off one nearly done.
	prey = alone()
	local near = bugAt(spot + Vector3.new(-6, 0, 12), "Sahur")
	local bomberFar = bugAt(spot + Vector3.new(-6, 0, 17), "Crocodilo")
	check(bomberFar.Model:GetAttribute("CritterRanged") == true, "The bomber isn't marked as ranged")
	for _, bug in { near, bomberFar } do
		(bug :: any).Foe = prey
	end
	KaijuServer._think(prey, now, 0.15)
	check(prey.Target == bomberFar, "Your kaiju went for the nearer critter, not the bomber")
	prey = alone()
	local healthy = bugAt(spot + Vector3.new(-6, 0, 12), "Sahur")
	local weak = bugAt(spot + Vector3.new(-6, 0, 15), "Patapim")
	weak.Humanoid.Health = weak.Humanoid.MaxHealth * 0.1
	for _, bug in { healthy, weak } do
		(bug :: any).Foe = prey
	end
	KaijuServer._think(prey, now, 0.15)
	check(prey.Target == weak, "Your kaiju left one nearly done for")
	-- A heavy sweeps through the swarm: the critters in its arc are hit too,
	-- one behind it isn't.
	prey = alone()
	local r = prey.Fighter.Reach * 0.8
	local p0 = prey.Root.Position
	local front = bugAt(p0 + Vector3.new(0, 0, -r), "Sahur")
	local beside = bugAt(p0 + Vector3.new(r * math.sin(math.rad(40)), 0, -r * math.cos(math.rad(40))), "Patapim")
	local behind = bugAt(p0 + Vector3.new(0, 0, r), "Tralalero")
	for _, bug in { front, beside, behind } do
		local bb = bug :: any
		bb.NextDodge, bb.NextMove = math.huge, math.huge
	end
	prey.Target = front
	prey.Fighter.Action = { Kind = "Heavy", At = now }
	KaijuServer._think(prey, now, 0.15)
	check(front.Humanoid.Health < front.Humanoid.MaxHealth, "The heavy missed its foe")
	check(beside.Humanoid.Health < beside.Humanoid.MaxHealth, "The heavy didn't sweep through the one beside")
	check(behind.Humanoid.Health == behind.Humanoid.MaxHealth, "The heavy hit one behind it")
	local swept = beside.Humanoid.MaxHealth - beside.Humanoid.Health
	local struck = front.Humanoid.MaxHealth - front.Humanoid.Health
	check(swept < struck, "The sweep hit as hard as the blow")

	-- A short fight walked through: three kaiju on six critters for twelve
	-- seconds. Each its own foe all along, the critters two on each, never
	-- piled up, and the critters' moves used.
	reset()
	local kinds = { "Sahur", "Tralalero", "Patapim", "Crocodilo", "Sahur", "Patapim" }
	for i, species in kinds do
		local turn = i * math.pi * 2 / #kinds
		local bug = bugAt(spot + Vector3.new(math.cos(turn) * 14, 0, 3 + math.sin(turn) * 14), species)
		bug.LastAttack = 0
	end
	local function walkAll(dt: number)
		local movers = {}
		for _, p in team do
			table.insert(movers, p)
		end
		for _, bug in bugs do
			table.insert(movers, bug)
		end
		for _, m in movers do
			local target = m.Humanoid.MovingTo
			if target then
				local from = m.Root.Position
				local d = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
				local stride = math.min(d.Magnitude, (m.Humanoid.WalkSpeed or 0) * dt)
				if d.Magnitude > 1e-3 and stride > 0 then
					m.Root.CFrame = CFrame.new(from + d.Unit * stride)
				end
			end
		end
	end
	local function flatGap(p: Vector3, q: Vector3): number
		local d = p - q
		return Vector3.new(d.X, 0, d.Z).Magnitude
	end
	-- The critters the team plan can share out: those near you, and any a
	-- kaiju's already on a little further off. (Fewer than the kaiju, as
	-- critters hop back, dash past or keep their distance, and the kaiju
	-- share them by rights.)
	local function inReach(): number
		local listed, count = {}, 0
		for _, bug in bugs do
			if bug.Alive and (bug.Root.Position - rootA.Position).Magnitude <= Kaiju.Follow.Engage then
				listed[bug], count = true, count + 1
			end
		end
		for _, pet in team do
			local foe = pet.Target
			local near = foe and (foe.Root.Position - rootA.Position).Magnitude <= Kaiju.Follow.Engage + 12
			if foe and not listed[foe] and foe.Alive and near then
				listed[foe], count = true, count + 1
			end
		end
		return count
	end
	local ticks, apartTicks, evenTicks, piled, petGap, bugGap, gaps = 0, 0, 0, 0, 0, 0, 0
	local named = {}
	table.clear(fxs)
	for step = 1, 80 do
		now += 0.15
		tick(team)
		local spare = inReach() >= #team
		walkAll(0.15)
		for _, bug in bugs do
			local name = bug.Model:GetAttribute("ActionName")
			if name then
				named[name] = true
			end
		end
		if step > 20 then
			ticks += 1
			if distinct(team) or not spare then
				apartTicks += 1
			end
			n = onEach(team)
			local most, least = 0, math.huge
			for _, p in team do
				most, least = math.max(most, n[p]), math.min(least, n[p])
			end
			if most - least <= 1 then
				evenTicks += 1
			end
			local closest = math.huge
			for i = 1, #team do
				for j = i + 1, #team do
					closest = math.min(closest, flatGap(team[i].Root.Position, team[j].Root.Position))
				end
			end
			petGap += closest
			if closest < 1.5 then
				piled += 1
			end
			-- Critters on the same kaiju: how close the nearest two are.
			for _, p in team do
				local on = {}
				for _, bug in bugs do
					if bug.Foe == p then
						table.insert(on, bug.Root.Position)
					end
				end
				if #on >= 2 then
					local near = math.huge
					for i = 1, #on do
						for j = i + 1, #on do
							near = math.min(near, flatGap(on[i], on[j]))
						end
					end
					bugGap += near
					gaps += 1
				end
			end
		end
	end
	print(
		string.format(
			"  team fight: each its own foe %d/%d ticks, critters even %d/%d, kaiju %.1f studs apart (%d piled), critters on one %.1f apart",
			apartTicks,
			ticks,
			evenTicks,
			ticks,
			petGap / ticks,
			piled,
			bugGap / math.max(1, gaps)
		)
	)
	check(apartTicks == ticks, "Kaiju doubled up with critters to spare")
	check(evenTicks >= ticks * 0.9, "Critters weren't spread over the kaiju")
	check(petGap / ticks >= 3, "Kaiju bunched up")
	check(piled <= ticks * 0.05, "Kaiju on top of each other")
	check(gaps > 0 and bugGap / gaps >= 2.5, "Critters piled on a kaiju")
	local used = 0
	for _, m in Kaiju.BugMoves do
		if named[m.Name] then
			used += 1
		end
	end
	check(used >= 2, "The critters hardly used their moves: " .. used)
	-- Every blow, hop and move in it drawn at its fighter's size (FxSize):
	-- a pet's at a pet's, a critter's at a critter's, none at a player's.
	local petSize, sized, raw = Kaiju.size(Kaiju.Scale.Pet), {}, 0
	local drawn = { Swing = true, DodgeRoll = true, EnemySwing = true, Nova = true, Shot = true, Zone = true }
	for _, entry in fxs do
		if entry[1] == "Sized" then
			sized[entry[2]] = (sized[entry[2]] or 0) + 1
		elseif drawn[entry[1]] then
			raw += 1
		end
	end
	check(raw == 0, raw .. " creature effects drawn at a player's size")
	check((sized[petSize] or 0) > 0, "No kaiju effects at a pet's size")
	check((sized[Kaiju.Bug.Size] or 0) > 0, "No critter effects at a critter's size")

	-- A pack shares its foes too: two wild kaiju on two of yours take one
	-- each; on one, both, from opposite sides.
	reset()
	local pack
	for _, candidate in KaijuWilds._packs do
		if #candidate.Members >= 2 then
			pack = candidate
			break
		end
	end
	check(pack ~= nil, "No pack of two")
	local w1, w2 = pack.Members[1], pack.Members[2]
	local here = spot + Vector3.new(0, 0, 30)
	for i, w in { w1, w2 } do
		local we = w.Enemy :: any
		we.Home = here
		we.Root.CFrame = CFrame.new(here + Vector3.new((i - 1.5) * 8, 0, 0))
		w.Engaged[a] = now
		w.Taming, w.Plan = nil, nil
		we.StunUntil, we.FoeVictim, we.LastPet = 0, nil, nil
	end
	team[1].Root.CFrame = CFrame.new(here + Vector3.new(-6, 0, -6))
	team[2].Root.CFrame = CFrame.new(here + Vector3.new(6, 0, -6))
	team[3].Root.CFrame = CFrame.new(spot + Vector3.new(0, 0, -90))
	for _ = 1, 2 do
		KaijuWilds._brain(w1.Enemy, now)
		KaijuWilds._brain(w2.Enemy, now)
	end
	check(
		w1.Enemy.Foe ~= nil and w2.Enemy.Foe ~= nil and w1.Enemy.Foe ~= w2.Enemy.Foe,
		"A pack on two kaiju piled onto one"
	)
	team[2].Root.CFrame = CFrame.new(spot + Vector3.new(0, 0, -95))
	for _ = 1, 2 do
		KaijuWilds._brain(w1.Enemy, now)
		KaijuWilds._brain(w2.Enemy, now)
	end
	check(w1.Enemy.Foe == team[1] and w2.Enemy.Foe == team[1], "A pack on one kaiju didn't both go in")
	check(
		w1.Fighter.Flank and w2.Fighter.Flank and w1.Fighter.Flank:Dot(w2.Fighter.Flank) < -0.99,
		"A pack on one didn't flank it"
	)
	for _, w in { w1, w2 } do
		local we = w.Enemy :: any
		table.clear(w.Engaged)
		we.FoeVictim, we.Foe = nil, nil
		w.Fighter.Flank, w.Fighter.Apart = nil, nil
		KaijuFighter.calm(w.Fighter)
	end
	clearCritters()
	for i, p in team do
		p.Target, p.Fighter.Flank, p.Fighter.Apart = nil, nil, nil
		p.Root.CFrame = CFrame.new(center + Vector3.new((i - 2) * 4, 0, 4))
	end
	rootA.CFrame = CFrame.new(center)
end
teamFights()

-- Kaiju battles ---------------------------------------------------------------------------------------------
-- Asked and accepted; each side's kaiju in their default places (the
-- sturdy ones in front, a Razorback behind), moved about, both ready; then
-- they fight it out by themselves, each side's shared out over the other's,
-- till one side's down: the result to both, EXP, the losers knocked out
-- for real. Walking off forfeits.
do
	-- (In a function of its own: this file is at its limit of locals.)
	local run = function()
		local KaijuBattle = shared("KaijuBattle")
		local KaijuBattles = serverModule("KaijuBattles")
		KaijuBattles.clock = function()
			return now
		end
		KaijuBattles.start()
		for _, name in
			{ "KaijuBattleAsk", "KaijuBattleRespond", "KaijuBattleFormation", "KaijuBattleReady", "KaijuBattleLeave" }
		do
			check(registered[name] ~= nil, name .. " isn't a request")
		end
		Kaiju.SlotLevels = { 1, 1, 1 }
		clearCritters()
		for _, p in { a, b } do
			for _, key in { "CombatSession", "MatchId", "DungeonId", "Expedition", "Hunt", "Spar" } do
				p:SetAttribute(key, nil)
			end
			p:SetAttribute("Outpost", true)
		end
		local spot = center + Vector3.new(-320, 5, 60)
		rootA.CFrame = CFrame.new(spot)
		rootB.CFrame = CFrame.new(spot + Vector3.new(0, 0, 24))
		now += 10
		KaijuServer.reviveAll(b)
		KaijuServer._upkeep(a, now)
		KaijuServer._upkeep(b, now)
		local teamA, teamB = KaijuServer.team(a), KaijuServer.team(b)
		check(#teamA == 3 and #teamB == 3, "Not three out each for a battle: " .. #teamA .. "/" .. #teamB)
		for _, pet in teamA do
			pet.Humanoid.MaxHealth, pet.Humanoid.Health = 1e5, 1e5
		end
		for _, pet in teamB do
			pet.Humanoid.Health = math.max(1, math.floor(pet.Humanoid.MaxHealth * 0.05))
		end
		for _, pet in table.move(teamB, 1, 3, 4, table.clone(teamA)) do
			pet.RecallUntil, pet.StunUntil, pet.Target, pet.Plan = 0, 0, nil, nil
			settle(pet.Fighter)
		end
		local function told(player, kind)
			local last = nil
			for _, entry in socials do
				if entry[1] == player and entry[2] == kind then
					last = entry
				end
			end
			return last
		end
		-- Too far apart: no ask.
		rootB.CFrame = CFrame.new(spot + Vector3.new(0, 0, 90))
		check(not registered.KaijuBattleAsk(a, b.UserId).Ok, "Asked someone too far off")
		rootB.CFrame = CFrame.new(spot + Vector3.new(0, 0, 24))
		now += 2
		-- Asked: a card for them; asked again, no.
		table.clear(socials)
		check(registered.KaijuBattleAsk(a, b.UserId).Ok, "Couldn't ask for a kaiju battle")
		local card = told(b, "KaijuBattleAsk")
		check(card ~= nil and card[3] == a.UserId, "No card for the one asked")
		now += 2
		check(not registered.KaijuBattleAsk(a, b.UserId).Ok, "Asked twice")
		-- Accepted: the formation phase, each side in its default places.
		check(registered.KaijuBattleRespond(b, a.UserId, true).Ok, "Couldn't accept")
		local battle = KaijuBattles.of(a)
		check(battle ~= nil and KaijuBattles.of(b) == battle and battle.Phase == "Formation", "No battle")
		check(
			a:GetAttribute("KaijuBattle") == battle.Id and b:GetAttribute("KaijuBattle") == battle.Id,
			"Not marked in it"
		)
		local stateA = told(a, "KaijuBattle")
		stateA = stateA and stateA[3]
		check(stateA and stateA.Side == "A" and stateA.Theirs == nil, "A foe's places shown before it starts")
		check(stateA and #stateA.Units == 3, "Your kaiju in it, before it starts: " .. (stateA and #stateA.Units or 0))
		for _, pet in teamA do
			local cellId = battle.Formation[a][pet.Record.Id]
			local cell = KaijuBattle.cell(cellId)
			check(cell ~= nil, "A kaiju of yours has no place")
			check(
				cell and (cell.Row == "Back") == (pet.Record.Species == "Razorback"),
				pet.Record.Species .. " isn't in its default row: " .. tostring(cellId)
			)
			local orders = KaijuServer.battle(pet, now)
			check(orders and orders.Spot and not orders.Foe, "In the formation, a kaiju didn't make for its place")
		end
		-- Mid-battle: no recall, no other team.
		check(not registered.KaijuRecall(a).Ok, "Recalled mid-battle")
		-- Placing: a bad formation refused; a good one taken.
		local ids = {}
		for id in battle.Formation[a] do
			table.insert(ids, id)
		end
		table.sort(ids)
		check(
			not registered.KaijuBattleFormation(
				a,
				{ [ids[1]] = "FrontLeft", [ids[2]] = "FrontLeft", [ids[3]] = "BackLeft" }
			).Ok,
			"Two on one place"
		)
		check(not registered.KaijuBattleFormation(a, { [ids[1]] = "FrontLeft" }).Ok, "A kaiju left without a place")
		check(
			not registered.KaijuBattleFormation(
				a,
				{ nope = "FrontLeft", [ids[2]] = "BackLeft", [ids[3]] = "BackRight" }
			).Ok,
			"Placed another's kaiju"
		)
		check(
			not registered.KaijuBattleFormation(a, { [ids[1]] = "Moon", [ids[2]] = "BackLeft", [ids[3]] = "BackRight" }).Ok,
			"Placed off the field"
		)
		local wanted = { [ids[1]] = "BackLeft", [ids[2]] = "FrontRight", [ids[3]] = "BackRight" }
		check(registered.KaijuBattleFormation(a, wanted).Ok, "A good formation refused")
		check(battle.Formation[a][ids[1]] == "BackLeft", "The formation wasn't taken")
		-- Both ready: it starts, each kaiju at its place, facing the other side.
		check(registered.KaijuBattleReady(a).Ok and battle.Phase == "Formation", "One ready started it")
		check(registered.KaijuBattleReady(b).Ok and battle.Phase == "Battle", "Both ready didn't start it")
		local started = now
		check(not registered.KaijuBattleFormation(a, wanted).Ok, "Placed after it started")
		for _, pet in teamA do
			local at = KaijuBattle.cellSpot(battle.Field, "A", battle.Formation[a][pet.Record.Id])
			local off = Vector3.new(pet.Root.Position.X - at.X, 0, pet.Root.Position.Z - at.Z).Magnitude
			check(off < 1, "A kaiju didn't start at its place: " .. off)
		end
		local frontB = battle.Field.Center + battle.Field.Axis * KaijuBattle.Field.Front
		local backA = battle.Field.Center - battle.Field.Axis * KaijuBattle.Field.Back
		check(
			(frontB - rootB.Position).Magnitude < (backA - rootB.Position).Magnitude,
			"The sides are the wrong way round"
		)
		stateA = told(a, "KaijuBattle")[3]
		check(
			stateA.Phase == "Battle" and stateA.Theirs ~= nil and #stateA.Units == 6,
			"Started, the foe's places still hidden"
		)
		-- Each has a foe on the other side.
		for _, pet in teamA do
			local orders = KaijuServer.battle(pet, now)
			check(orders and orders.Foe and orders.Foe.Owner == b, "A kaiju of yours has no foe in the battle")
		end
		-- They fight it out: yours win (theirs came in nearly down).
		table.clear(notes)
		local expBefore = {}
		for _, pet in teamA do
			expBefore[pet.Record.Id] = pet.Record.Exp + pet.Record.Level * 1e6
		end
		local landed = false
		for _ = 1, 600 do
			now += 0.15
			for _, pet in KaijuServer.all() do
				if pet.Owner == a or pet.Owner == b then
					KaijuServer._think(pet, now, 0.15)
					-- (They walk where they're told: a step's worth.)
					local h, from = pet.Humanoid, pet.Root.Position
					local to = h.MovingTo
					if to then
						local way = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
						local step = math.min(way.Magnitude, (h.WalkSpeed or 16) * 0.15)
						if step > 0.01 then
							pet.Root.CFrame = CFrame.new(from + way.Unit * step)
						end
					end
				end
			end
			flush()
			for _, pet in teamB do
				if pet.Humanoid.Health < pet.Humanoid.MaxHealth * 0.05 then
					landed = true
				end
			end
			KaijuBattles.step(battle, now)
			if battle.Phase == "Over" then
				break
			end
		end
		check(landed, "No blow landed on the other side's kaiju")
		check(battle.Phase == "Over", "The battle never ended")
		check(battle.Result and battle.Result[a] == "Win" and battle.Result[b] == "Lose", "The wrong side won")
		check(noted(a, "Your kaiju beat") and noted(b, "kaiju won the battle"), "Not told who won")
		local downs = 0
		for _, record in profiles[b].Kaiju.List do
			if record.Down and record.DownUntil then
				downs += 1
			end
		end
		check(downs >= 3, "The losers' kaiju weren't knocked out for real: " .. downs)
		check(now - started < KaijuBattle.BattleSeconds - 1, "It ran out of time instead of being won")
		local gained = false
		for _, pet in teamA do
			if pet.Record.Exp + pet.Record.Level * 1e6 > expBefore[pet.Record.Id] then
				gained = true
			end
		end
		check(gained, "The winners' kaiju gained no EXP")
		check(told(a, "KaijuBattle")[3].Result == "Win", "The result wasn't shown")
		-- A moment later it's gone.
		now += KaijuBattle.OverSeconds + 0.1
		KaijuBattles.step(battle, now)
		check(KaijuBattles.of(a) == nil and a:GetAttribute("KaijuBattle") == nil, "The battle never closed")
		check(registered.KaijuRecall(a).Ok, "Still held as in a battle")
		-- Walking off forfeits.
		KaijuServer.reviveAll(b)
		now += 5
		KaijuServer._upkeep(b, now)
		check(registered.KaijuBattleAsk(b, a.UserId).Ok, "Couldn't ask again")
		check(registered.KaijuBattleRespond(a, b.UserId, true).Ok, "Couldn't accept again")
		battle = KaijuBattles.of(a)
		check(battle and battle.A == b, "The second battle didn't start")
		rootA.CFrame = CFrame.new(spot + Vector3.new(0, 0, KaijuBattle.Leash + 30))
		KaijuBattles.step(battle, now + 0.25)
		check(
			battle.Phase == "Over" and battle.Result[b] == "Win" and battle.Result[a] == "Lose",
			"Walking off didn't forfeit"
		)
		registered.KaijuBattleLeave(b)
		check(KaijuBattles.of(b) == nil, "Closing didn't let you go")
		now += KaijuBattle.OverSeconds + 0.1
		KaijuBattles.step(battle, now)
		check(KaijuBattles.of(a) == nil, "The forfeit never closed")
		rootA.CFrame = CFrame.new(spot)
		for _, pet in teamA do
			pet.Humanoid.MaxHealth, pet.Humanoid.Health = pet.Stats.Health, pet.Stats.Health
		end
	end
	run()
end
-- Gem raids: your team all down out past the core, the critters out for
-- you turn snatchers and more come through; they trip you, grab the newest
-- gems of this trip's haul, hold them up and run for a rift that waits for
-- them; bonked or knocked out they drop it back to you. (In a function of
-- its own: this file is at Luau's 200 locals.)
;
(function()
	clearCritters()
	table.clear(notes)
	table.clear(fxs)
	b:SetAttribute("SparDown", nil)
	local Raid = Frontier.Raid
	local downs = {}
	KaijuWilds.knockDown = function(player, seconds, by)
		table.insert(downs, { player, seconds, by })
		player:SetAttribute("SparDown", now + seconds)
		return true
	end
	check(KaijuServer.onTeamDown == FrontierServer.raid, "A team all down doesn't start a raid")
	local profile = profiles[b]
	profile.Gems = {}
	local function has(id)
		for _, gem in profile.Gems do
			if gem.Id == id then
				return true
			end
		end
		return false
	end
	-- The haul: only gems mined out past the core.
	stand(center + Vector3.new(60, 5, 0))
	local coreGem = { Id = "core-1", Tier = "Common", Element = "Fire" }
	table.insert(profile.Gems, coreGem)
	FrontierServer.mined(b, coreGem)
	check(FrontierServer._hauls[b] == nil, "A gem mined in the core joined the haul")
	FrontierServer._raids[b] = nil
	check(not FrontierServer.raid(b), "A raid in the core")
	stand(center + Vector3.new(200, 5, 0))
	for i = 1, 4 do
		local gem = { Id = "haul-" .. i, Tier = if i == 4 then "Rare" else "Common", Element = "Frost" }
		table.insert(profile.Gems, gem)
		FrontierServer.mined(b, gem)
	end
	check(FrontierServer._hauls[b] and #FrontierServer._hauls[b] == 4, "The trip's haul")
	-- The raid: snatchers come through for them.
	check(FrontierServer.raid(b), "No raid with the team down out there")
	check(noted(b, "smell your gems"), "Not told of the raid")
	check(not FrontierServer.raid(b), "A second raid straight after the first")
	for _ = 1, 40 do
		now += 0.25
		runDelayed()
	end
	local raiders = critterFor(b)
	local melee = {}
	local snatchers = 0
	for _, enemy in raiders do
		local entry = KaijuWilds._wilds[enemy]
		if entry.Raider and enemy.Model:GetAttribute("Raider") then
			snatchers += 1
		end
		if entry.Raider and not Kaiju.isRanged(entry.Species) then
			table.insert(melee, enemy)
		end
	end
	check(snatchers == #raiders and snatchers >= Raid.Size, "Not all snatchers: " .. snatchers .. "/" .. #raiders)
	check(#melee >= 3, "Too few snatchers to grab with")
	local function near(enemy)
		enemy.Root.CFrame = CFrame.new(rootB.Position + Vector3.new(3, 0, 0))
	end
	-- The trip: wound up on its cast bar, then they're down.
	local thief = melee[1]
	near(thief)
	thief.NextTrip, thief.NextMove, thief.LastAttack = 0, now + 60, now
	KaijuWilds._brain(thief, now)
	check(thief.Model:GetAttribute("ActionName") == "Trip", "No trip wound up on the cast bar")
	check(#downs == 0, "Tripped before the wind-up was over")
	now += Raid.Trip.Windup + 0.05
	near(thief)
	KaijuWilds._brain(thief, now)
	check(#downs == 1 and downs[1][1] == b and downs[1][3] == "Snatcher", "The trip didn't knock them down")
	check(downs[1][2] == Raid.Trip.Down, "Down for the wrong time")
	-- Down: it goes in for a grab, and off with the newest gem of the haul.
	near(thief)
	KaijuWilds._brain(thief, now)
	check(thief.Model:GetAttribute("ActionName") == "Snatch", "No grab at a player down")
	now += Raid.Snatch.Windup + 0.05
	KaijuWilds._brain(thief, now)
	local wild = KaijuWilds._wilds[thief]
	check(wild.Loot and wild.Loot.Id == "haul-4", "It didn't take the newest gem of the haul")
	check(not has("haul-4") and has("core-1"), "The pouch after the grab")
	check(noted(b, "snatched your"), "Not told what was snatched")
	check(thief.Model:GetAttribute("CarryingGem") == "Rare", "Not held up for all to see")
	-- (The very stone: what the clients build over its head, CritterFx.)
	check(thief.Model:GetAttribute("CarriedGemId") == "haul-4", "Not the stone it took over its head")
	check(thief.Model:GetAttribute("CarriedGemElement") == wild.Loot.Element, "The stone over its head isn't its element")
	check(thief.Model:FindFirstChild("StolenGem") == nil, "A made-up stone over its head")
	check(thief.Model:GetAttribute("ActionKind") == "Buff", "Its arms aren't up")
	local giggled = false
	for _, f in fxs do
		if f[1] == "CritterGiggle" and f[3] == "Cackle" then
			giggled = true
		end
	end
	check(giggled, "No cackle")
	local escape = wild.Carry.Life
	check(escape and escape.HopAt - now >= Raid.Carry.Wait - 0.2, "Its rift doesn't wait for it")
	local spot = wild.Carry.Spot
	check(
		Vector3.new(spot.X - rootB.Position.X, 0, spot.Z - rootB.Position.Z).Magnitude >= 12,
		"Its rift opened on them"
	)
	-- Two more grabs this knock-down at most, then the rest taunt.
	for i = 2, 3 do
		local other = melee[i]
		near(other)
		KaijuWilds._brain(other, now)
	end
	now += Raid.Snatch.Windup + 0.05
	for i = 2, 3 do
		near(melee[i])
		KaijuWilds._brain(melee[i], now)
	end
	local carrying = 0
	for _, enemy in raiders do
		local entry = KaijuWilds._wilds[enemy]
		if entry and entry.Loot then
			carrying += 1
		end
	end
	check(carrying == 3 and not has("haul-3") and not has("haul-2") and has("haul-1"), "Three grabs a knock-down")
	if melee[4] then
		near(melee[4])
		KaijuWilds._brain(melee[4], now)
		check(melee[4].Model:GetAttribute("ActionName") ~= "Snatch", "A fourth grab in one knock-down")
	end
	-- Running off with it, giggling, the gem gone through its rift.
	thief.Root.CFrame = CFrame.new(spot + Vector3.new(0, 2, 0))
	now = escape.HopAt + 0.05
	KaijuWilds._brain(thief, now)
	check(not thief.Alive and KaijuWilds._wilds[thief] == nil, "It never hopped into its rift")
	check(noted(b, "got away with"), "Not told it got away")
	check(not has("haul-4"), "A gem that got away came back")
	-- Bonked: it drops it, and the gem flies back to them.
	local bonked = melee[2]
	check(KaijuWilds.bonk(bonked, b, rootB.Position), "A snatcher couldn't be bonked")
	check(has("haul-3") and KaijuWilds._wilds[bonked].Loot == nil, "A bonked snatcher kept the gem")
	check(bonked.Model:GetAttribute("CarryingGem") == nil, "Still holding it up")
	check(bonked.Model:GetAttribute("CarriedGemId") == nil, "Its stone still over its head")
	check(noted(b, "Recovered. Your"), "Not told it came back")
	local flew = false
	for _, f in fxs do
		if f[1] == "GemRecovered" then
			flew = true
		end
	end
	check(flew, "The gem didn't fly back")
	-- Knocked out: the same.
	local beaten = melee[3]
	Enemies.damage(beaten, beaten.Humanoid.MaxHealth * 10, b)
	check(has("haul-2"), "A snatcher knocked out kept the gem")
	-- Nothing left to take: it blows a raspberry and slips away.
	if melee[4] and melee[4].Alive then
		FrontierServer._hauls[b] = {}
		b:SetAttribute("SparDown", now + 4) -- (a new knock-down)
		near(melee[4])
		melee[4].Action = nil
		KaijuWilds._brain(melee[4], now)
		now += Raid.Snatch.Windup + 0.05
		KaijuWilds._brain(melee[4], now)
		local entry = KaijuWilds._wilds[melee[4]]
		check(entry == nil or entry.Leaving, "A snatcher with nothing to take stayed")
	end
	-- Back in the core, the haul is safe.
	b:SetAttribute("SparDown", nil)
	FrontierServer._hauls[b] = { { Id = "haul-1" } }
	stand(center + Vector3.new(60, 5, 0))
	FrontierServer._step(0.5)
	check(FrontierServer._hauls[b] == nil, "The haul wasn't safe back in the core")
	clearCritters()
	FrontierServer._raids[b] = nil
end)()

-- The Rift (Server.RiftServer) -----------------------------------------------------------------------------
-- Through a vein's gate: alone you're warned, your party joins you; each
-- island's pack comes up, and cleared, its fire dies and you each find a
-- gem; knocked out on the path you're robbed and thrown home; at the boss
-- you're kept down to choose (RESTORE for coins, or home with what you
-- found); the boss calls critters through as it weakens; off the path into
-- the lava you're back on the last island, hurt; beaten, everyone's paid
-- and the way home opens. Nothing of the Outpost's comes for you in there.
;(function()
	local RiftRun = shared("RiftRun")
	local built, opened, homesOpened = {}, {}, 0
	server.RiftWorld = {
		build = function(id, origin)
			local base = origin.Position
			local folder = make("Folder", { Name = "Rift_" .. id })
			folder.Parent = workspaceObject
			local rooms, gates = {}, {}
			for i = 1, RiftRun.Rooms do
				rooms[i] = { Center = base + Vector3.new(0, 0, -92 * i), Radius = 28 }
				gates[i] = make("Model", { Name = "FireGate" })
			end
			local home = make("Model", { Name = "WayHome" })
			make("Part", { Name = "Opening", CFrame = CFrame.new(base + Vector3.new(0, 7, -500)) }).Parent = home
			local world = {
				Folder = folder,
				Origin = origin,
				Start = CFrame.new(base + Vector3.new(0, 3, 4)),
				Rooms = rooms,
				Boss = { Center = base + Vector3.new(0, 4, -476), Radius = 46 },
				Gates = gates,
				Exit = make("Part", { CFrame = CFrame.new(base + Vector3.new(0, 7, 12)) }),
				Home = home,
			}
			table.insert(built, world)
			return world
		end,
		openGate = function(gate)
			opened[gate] = true
		end,
		openHome = function()
			homesOpened += 1
		end,
	}
	local parties = {}
	server.Party = {
		of = function(player)
			return parties[player]
		end,
	}
	local restored = {}
	server.Restores = {
		give = function(player)
			restored[player] = (restored[player] or 0) + 1
			return 40
		end,
	}
	local awarded = 0
	GemsStub.award = function(player, source, opts)
		awarded += 1
		local gem = {
			Id = PlayerData.newGemId(),
			Element = "Fire",
			Tier = "Common",
			Size = 3,
			Clarity = 3,
			Cut = 3,
			Source = source,
			Luck = opts and opts.Luck,
		}
		table.insert(profiles[player].Gems, gem)
		return gem
	end
	PlayerData.spendCoins = function(player, amount)
		if profiles[player].Coins < amount then
			return false
		end
		profiles[player].Coins -= amount
		return true
	end
	services.Debris = services.Debris or { AddItem = function() end }
	local RiftServer = serverModule("RiftServer")
	local site = { Spawn = CFrame.new(outpost + Vector3.new(0, 3, 0)) }
	RiftServer.start(site)
	for _, name in { "RiftEnter", "RiftLeave", "RiftChoice", "RiftPeek" } do
		check(registered[name] ~= nil, name .. " isn't a request")
	end
	local gate = make("Part", { CFrame = CFrame.new(outpost + Vector3.new(420, 5, 0)) })
	RiftServer.gateAt = function(index)
		return if index == 2 then gate else nil
	end
	-- (Back to plain miners in the Outpost, nothing about them.)
	clearCritters()
	KaijuWilds.rift = function()
		return nil -- (no tear to wait on: things come straight through)
	end
	for _, p in { a, b } do
		for _, key in { "CombatSession", "MatchId", "DungeonId", "Expedition", "Hunt", "Spar", "SparDown", "SparWith", "KaijuBattle" } do
			p:SetAttribute(key, nil)
		end
		p:SetAttribute("Outpost", true)
		profiles[p].Gems, profiles[p].Coins = {}, 0
		local h = p.Character:FindFirstChildOfClass("Humanoid")
		h.MaxHealth, h.Health = 100, 100
	end
	a.Character.PrimaryPart, b.Character.PrimaryPart = rootA, rootB
	rootA.CFrame = CFrame.new(outpost + Vector3.new(-300, 0, 0))
	local function enter(p, vein)
		return registered.RiftEnter(p, vein)
	end
	-- Not from afar, nor through a gate that isn't one.
	check(not enter(a, 2).Ok and enter(a, 2).Message == "Walk up to a Rift Gate first.", "Into the Rift from afar")
	rootA.CFrame = CFrame.new(gate.Position + Vector3.new(4, 0, 0))
	check(not enter(a, 7).Ok, "Through a gate that isn't one")
	-- Alone: warned, at the gate and in there.
	local peeked = registered.RiftPeek(a)
	check(peeked.Ok and peeked.Solo == true and peeked.Party == 1 and not peeked.Joining, "Going alone isn't flagged")
	local went = enter(a, 2)
	check(went.Ok and went.Runners == 1, "Couldn't go through the gate: " .. tostring(went.Message))
	local run = RiftServer.runOf(a)
	check(run and a:GetAttribute("RiftRun") == run.Id, "No trip for them")
	local world = built[#built]
	check((rootA.Position - world.Start.Position).Magnitude < 8, "They didn't arrive on the landing")
	check(noted(a, "You're in the Rift alone"), "Not warned in there about going alone")
	check(not enter(a, 2).Ok, "Into the Rift twice")
	check(not FrontierServer._eligible(a), "The Outpost's critters still come for someone in the Rift")
	check(a:GetAttribute("RiftRoom") == 1 and a:GetAttribute("RiftLeft") == RiftRun.foeCount(1, 1), "The first island's pack isn't up")
	local isBoss = false
	for enemy in run.Foes do
		local entry = KaijuWilds._wilds[enemy]
		check(entry and entry.Stay and entry.Wander and enemy.Model:GetAttribute("RiftRun") == run.Id, "A critter of the Rift that wanders off")
		check((enemy.Home - world.Rooms[1].Center).Magnitude <= world.Rooms[1].Radius, "A critter off its island")
		isBoss = isBoss or enemy.Model:GetAttribute("RiftBoss") == true
	end
	check(not isBoss, "A boss on the first island")
	-- One of their party joins them through any gate (it's on the path).
	parties[a] = { Members = { a, b } }
	parties[b] = parties[a]
	local seen = registered.RiftPeek(b)
	check(seen.Joining == true and seen.Solo == false, "A party member wasn't told they'd join")
	rootB.CFrame = CFrame.new(gate.Position + Vector3.new(-4, 0, 0))
	check(enter(b, 2).Ok and RiftServer.runOf(b) == run, "A party member didn't join the trip")
	check(a:GetAttribute("RiftRunners") == 2 and noted(a, "came through the gate"), "Not told who came through")
	-- An island cleared: its fire dies, a gem each, the next pack's up.
	local function clearIsland()
		for enemy in table.clone(run.Foes) do
			Enemies.damage(enemy, 1e6, a)
		end
		runDelayed()
	end
	clearIsland()
	check(opened[world.Gates[1]], "The first island's fire didn't die down")
	check(#profiles[a].Gems == 1 and #profiles[b].Gems == 1 and profiles[a].Gems[1].Source == "RiftCache", "No cache for clearing it")
	check(a:GetAttribute("RiftFound") == 1 and a:GetAttribute("RiftRoom") == 2, "Not shown the island's done")
	check(a:GetAttribute("RiftLeft") == RiftRun.foeCount(2, 2), "The second island's pack isn't sized for two")
	-- Off the path into the lava: back on the last island reached, hurt.
	rootA.CFrame = CFrame.new(world.Rooms[1].Center + Vector3.new(0, 3, 0))
	now += 0.25
	RiftServer._step(now)
	rootA.CFrame = CFrame.new(world.Rooms[1].Center + Vector3.new(30, -40, 0))
	now += 0.25
	RiftServer._step(now)
	local hA = a.Character:FindFirstChildOfClass("Humanoid")
	check((rootA.Position - world.Rooms[1].Center).Magnitude < 6, "Not put back on the island after the lava")
	check(hA.Health < hA.MaxHealth and hA.Health >= hA.MaxHealth * (1 - RiftRun.Fall.Hurt) - 1e-6, "The lava didn't hurt")
	hA.Health = hA.MaxHealth
	-- Knocked out on the path: robbed, and thrown home.
	b:SetAttribute("SparDown", now + 3)
	now += 0.25
	RiftServer._step(now)
	check(#profiles[b].Gems == 0 and noted(b, "The critters robbed you"), "Not robbed going down on the path")
	check(b:GetAttribute("RiftRun") ~= nil, "Thrown home before the critters had their giggle")
	now += 3
	runDelayed()
	check(b:GetAttribute("RiftRun") == nil and RiftServer.runOf(b) == nil, "Not thrown home")
	check((rootB.Position - site.Spawn.Position).Magnitude < 1 and b:GetAttribute("SparDown") == nil, "Not back at base, whole")
	check(a:GetAttribute("RiftRunners") == 1, "The trip still counts them")
	-- The rest of the path, then the throne island: the boss comes through.
	for _ = 2, RiftRun.Rooms do
		clearIsland()
	end
	check(a:GetAttribute("RiftRoom") == RiftRun.Rooms + 1 and a:GetAttribute("RiftBoss") == run.Boss.Name, "Not at the boss")
	check(run.BossEnemy == nil, "The boss came before anyone set foot there")
	rootA.CFrame = CFrame.new(world.Boss.Center + Vector3.new(0, 3, 20))
	now += 0.25
	RiftServer._step(now)
	runDelayed()
	local boss = run.BossEnemy
	check(boss and boss.Alive and boss.Model:GetAttribute("RiftBoss") == true, "The boss didn't come through")
	local isOne = false
	for _, spec in shared("DungeonRules").Bosses do
		isOne = isOne or spec.Id == run.Boss.Id
	end
	check(isOne and KaijuWilds._wilds[boss].Species == run.Boss.Id, "The boss isn't one of the brainrot bosses")
	check(string.find(boss.Model:GetAttribute("CombatTitle"), "RIFT BOSS", 1, true) ~= nil, "The boss isn't named one")
	check(boss.Humanoid.MaxHealth > Kaiju.Bug.Health * RiftRun.Boss.Health * 0.9, "The boss isn't tough")
	check(Kaiju.BugMoves[run.Boss.Id] ~= nil, "The boss has no move of its own")
	-- Weakened, it calls its critters through.
	boss.Humanoid.Health = boss.Humanoid.MaxHealth * 0.6
	now += 0.25
	RiftServer._step(now)
	runDelayed()
	check(run.Adds[1] and not run.Adds[2], "It didn't call critters through")
	local adds = 0
	for _ in run.Foes do
		adds += 1
	end
	check(adds == RiftRun.Boss.AddCount, "Not its critters through: " .. adds)
	-- Knocked out at the boss: kept down to choose.
	a:SetAttribute("SparDown", now + 3)
	now += 0.25
	RiftServer._step(now)
	check(type(a:GetAttribute("RiftFallen")) == "number" and a:GetAttribute("RiftRestore") == RiftRun.restoreCost(0), "Not asked what now")
	check(a:GetAttribute("SparDown") > now + RiftRun.Fallen - 1, "Not kept down while they choose")
	check(#profiles[a].Gems == RiftRun.Rooms, "Robbed at the boss")
	local poor = registered.RiftChoice(a, "Restore")
	check(not poor.Ok and string.find(poor.Message, "Not enough coins", 1, true), "Restored for nothing")
	profiles[a].Coins = 1000
	local team = KaijuServer.team(a)
	for _, pet in team do
		pet.Humanoid.Health = 1
	end
	check(registered.RiftChoice(a, "Restore").Ok, "Couldn't restore")
	check(profiles[a].Coins == 1000 - RiftRun.restoreCost(0), "RESTORE didn't cost its coins")
	check(a:GetAttribute("RiftFallen") == nil and a:GetAttribute("SparDown") == nil and hA.Health == hA.MaxHealth, "Not back on their feet")
	for _, pet in team do
		check(pet.Humanoid.Health == pet.Humanoid.MaxHealth, "Their kaiju weren't restored")
	end
	-- Down again: the next RESTORE costs more; back to base keeps what they found.
	a:SetAttribute("SparDown", now + 3)
	now += 0.25
	RiftServer._step(now)
	check(a:GetAttribute("RiftRestore") == RiftRun.restoreCost(1) and RiftRun.restoreCost(1) > RiftRun.restoreCost(0), "RESTORE didn't go up")
	check(registered.RiftChoice(a, "Home").Ok and a:GetAttribute("RiftRun") == nil, "Not home when they chose it")
	check(#profiles[a].Gems == RiftRun.Rooms, "Home from the boss, robbed")
	-- The last one out: the trip's gone, its critters and boss with it.
	check(run.Done and world.Folder.Destroyed and not boss.Alive, "The trip outlived its runners")
	-- A trip won: everyone paid, the way home open, and home they go.
	now += 1
	rootA.CFrame = CFrame.new(gate.Position)
	parties[a], parties[b] = nil, nil
	check(enter(a, 2).Ok, "Couldn't go in again")
	run = RiftServer.runOf(a)
	world = built[#built]
	check(world ~= built[1] and run.Id ~= nil, "Not a new trip")
	for _ = 1, RiftRun.Rooms do
		clearIsland()
	end
	rootA.CFrame = CFrame.new(world.Boss.Center + Vector3.new(0, 3, 20))
	now += 0.25
	RiftServer._step(now)
	runDelayed()
	local coins = profiles[a].Coins
	local found = #profiles[a].Gems
	Enemies.damage(run.BossEnemy, 1e9, a)
	check(run.Won and a:GetAttribute("RiftWon") == true and homesOpened >= 1, "Beating the boss didn't win the trip")
	check(profiles[a].Coins == coins + RiftRun.rewardCoins(RiftRun.Rooms) and #profiles[a].Gems == found + 1, "Not paid for the boss")
	check(restored[a] and noted(a, "is beaten!"), "No swings back or word of the win")
	-- (Far from a way home, you can't just leave; at it, you can.)
	check(not registered.RiftLeave(a).Ok, "Left the Rift from the middle of an island")
	now += RiftRun.Exit + 1
	RiftServer._step(now)
	check(a:GetAttribute("RiftRun") == nil and run.Done, "Not sent home after the win")
	-- Leaving through the landing's way home.
	now += 1
	rootA.CFrame = CFrame.new(gate.Position)
	check(enter(a, 2).Ok, "Couldn't go in a third time")
	world = built[#built]
	rootA.CFrame = CFrame.new(world.Exit.Position)
	check(registered.RiftLeave(a).Ok and a:GetAttribute("RiftRun") == nil, "Couldn't leave by the way home")
	-- (Pouches and coins back as they were for what follows.)
	for _, p in { a, b } do
		profiles[p].Gems, profiles[p].Coins = {}, 0
		p:SetAttribute("SparDown", nil)
	end
	print(string.format("  rift: %d caches handed out, %d trips", awarded, #built))
end)()

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
		"PASS: %d kaiju server checks (E abilities, the starter roll, your team, auto heal, fighting as a team, wild kaiju, duels, taming, kills, rifts, critters, stirring it up, the vein guardian, a wild kaiju's day, kaiju battles, gem raids, the Rift)",
		checks
	)
)
