-- Saga Outpost: the shared rules (Shared.Outpost) and the real OutpostServer
-- on Roblox instances (lune's roblox library), with stand-ins for saved data,
-- gems and the clock. Run by tests/run_outpost.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- A clock we drive, and task.delay that waits on it.
local now = 1000
local delayed = {}
local fakeTask = {
	delay = function(seconds, fn, ...)
		table.insert(delayed, { now + seconds, fn, table.pack(...) })
	end,
	spawn = function(fn, ...)
		-- Its own thread, so a wait inside only pauses that.
		local thread = coroutine.create(fn)
		local ok, problem = coroutine.resume(thread, ...)
		assert(ok, problem)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	wait = function()
		coroutine.yield()
	end,
}
local function advance(seconds)
	now += seconds
	for i = #delayed, 1, -1 do
		local d = delayed[i]
		if now >= d[1] then
			table.remove(delayed, i)
			d[2](table.unpack(d[3], 1, d[3].n))
		end
	end
end

local Rand = {}
Rand.__index = Rand
function Rand.new(seed)
	return setmetatable({ x = (seed or 7) % 2147483647 + 1 }, Rand)
end
function Rand:_n()
	self.x = (self.x * 48271) % 2147483647
	return self.x / 2147483647
end
function Rand:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_n()
end
function Rand:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_n())
end

local function signal()
	local fns = {}
	return {
		Connect = function(_, fn)
			table.insert(fns, fn)
		end,
		Fire = function(_, ...)
			for _, fn in fns do
				fn(...)
			end
		end,
	}
end

-- Services.
local workspaceRoot = R.Instance.new("Folder")
local replicated = R.Instance.new("Folder")
local sharedFolder = R.Instance.new("Folder")
local tags = {}
local CollectionService = {
	AddTag = function(_, instance, tag)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], instance)
	end,
}
local playerList = {}
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return playerList
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in playerList do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
}
local game = {
	GetService = function(_, name)
		return ({ CollectionService = CollectionService, Players = Players, ReplicatedStorage = replicated })[name]
	end,
}

-- Stand-ins for the systems it talks to.
local profiles = {}
local handlers = {}
local Shop = {
	register = function(name, fn)
		handlers[name] = fn
	end,
	reply = function(ok, message, extra)
		local r = { Ok = ok, Message = message }
		for k, v in extra or {} do
			r[k] = v
		end
		return r
	end,
}
local PlayerData = {
	get = function(p)
		return profiles[p]
	end,
	addCoins = function(p, n)
		profiles[p].Coins += n
	end,
	spendCoins = function(p, n)
		if profiles[p].Coins < n then
			return false
		end
		profiles[p].Coins -= n
		return true
	end,
	sync = function() end,
	milestone = function() end,
}
local gemsAwarded = 0
local Gems = {
	random = function()
		return Rand.new(11)
	end,
	award = function()
		gemsAwarded += 1
		return { Id = "G" .. gemsAwarded, Tier = "Rare", Element = "Shock" }
	end,
}
local MineWall = {
	recoverGear = function()
		return "Test Gear"
	end,
}
local Progress = { addXP = function() end }
local announced = {}
local ChatChannels = {
	announce = function(kind, text)
		table.insert(announced, { kind, text })
	end,
}
local TopPlayers = {
	board = function(name)
		return { { Name = "Ana", Value = if name == "Gear" then 210 else 7 } }
	end,
}

local loaded = {}
local function load(path, name, extra)
	local env = setmetatable({
		game = game,
		workspace = workspaceRoot,
		Instance = R.Instance,
		CFrame = R.CFrame,
		Vector3 = R.Vector3,
		Vector2 = R.Vector2,
		Color3 = R.Color3,
		UDim2 = R.UDim2,
		Enum = R.Enum,
		NumberRange = R.NumberRange,
		NumberSequence = R.NumberSequence,
		ColorSequence = R.ColorSequence,
		Random = Rand,
		task = fakeTask,
		typeof = R.typeof or typeof,
		os = {
			clock = function()
				return now
			end,
			time = function()
				return 86400 * 20000 + now
			end,
		},
		script = { Parent = { Parent = {} } },
		require = function(m)
			return extra[m]
		end,
	}, { __index = _G })
	local fn = luau.load(fs.readFile(ROOT .. "/" .. path), { debugName = name, environment = env })
	return fn()
end
local Rules = load("src/shared/Outpost.luau", "Outpost", {})
local GemConfig = {
	TierRank = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 },
	displayName = function()
		return "Rare Shock Gem"
	end,
}
local Mine = load("src/shared/Mine.luau", "Mine", {})

-- The rules ---------------------------------------------------------------------------
local counts = {}
for i = 0, 9999 do
	local size = Rules.rollSize(i / 10000)
	counts[size] = (counts[size] or 0) + 1
end
check(
	counts.Pebble > counts.Boulder
		and counts.Boulder > counts.Monolith
		and counts.Monolith > counts.Geode
		and counts.Geode > 0,
	"Rock sizes aren't weighted rarest-last"
)
check(
	Rules.damage("Survey", false) == 1
		and Rules.damage("Survey", true) == 2
		and Rules.damage("Plasma", false) == Rules.Picks.Plasma.Power,
	"Swing damage wrong"
)
check(
	Rules.tension(10, 10) == 0 and Rules.tension(0, 10) == 1 and math.abs(Rules.tension(3, 4) - 0.25) < 1e-9,
	"Tension wrong"
)
check(
	Rules.claimHolder({}, 1, 0) and Rules.claimHolder({ ClaimedBy = 1, ClaimUntil = 10 }, 1, 5),
	"Claim refused its holder"
)
check(
	not Rules.claimHolder({ ClaimedBy = 1, ClaimUntil = 10 }, 2, 5)
		and Rules.claimHolder({ ClaimedBy = 1, ClaimUntil = 10 }, 2, 10),
	"Claim didn't hold or expire"
)
do
	local full, step = Rules.Picks.Survey.Swings, Rules.FreeSwingSeconds
	local s, since = Rules.refillSurvey(10, 1000, 1000 + step * 3 + 5)
	check(s == 13 and since == 1000 + step * 3, "Free pick refill wrong")
	s = Rules.refillSurvey(full - 1, 0, step * 100)
	check(s == full, "Free pick overfilled")
	local _, waiting = Rules.refillSurvey(full, 0, 500)
	check(waiting == 500, "A full free pick kept its clock running")
end
for _, id in Rules.SizeOrder do
	local s = Rules.Sizes[id]
	check(s.Hp > 0 and s.Respawn > 0 and s.Coins[2] >= s.Coins[1], id .. " rock incomplete")
end

-- The server --------------------------------------------------------------------------
local World = load("src/server/World/OutpostWorld.luau", "OutpostWorld", {})
-- OutpostServer's requires resolve by name to the stand-ins above.
local Server = (function()
	sharedFolder.Name = "Shared"
	sharedFolder.Parent = replicated
	for _, name in { "Outpost", "GemConfig", "Mine" } do
		local stub = R.Instance.new("Folder")
		stub.Name = name
		stub.Parent = sharedFolder
	end
	local env_require = function(m)
		local key = if type(m) == "table" then m.__name elseif typeof(m) == "Instance" then m.Name else nil
		if key then
			return ({
				Outpost = Rules,
				GemConfig = GemConfig,
				Mine = Mine,
				OutpostWorld = World,
				Gems = Gems,
				ChatChannels = ChatChannels,
				MineWall = MineWall,
				PlayerData = PlayerData,
				Progress = Progress,
				Shop = Shop,
				TopPlayers = TopPlayers,
			})[key]
		end
		return nil
	end
	local named = setmetatable({}, {
		__index = function(_, key)
			return { __name = key }
		end,
	})
	local scriptStub = { Parent = setmetatable({ Parent = { World = named } }, { __index = named }) }
	replicated.Name = "ReplicatedStorage"
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				if name == "ReplicatedStorage" then
					return replicated
				end
				return ({ CollectionService = CollectionService, Players = Players })[name]
			end,
		},
		workspace = workspaceRoot,
		Instance = R.Instance,
		CFrame = R.CFrame,
		Vector3 = R.Vector3,
		Vector2 = R.Vector2,
		Color3 = R.Color3,
		UDim2 = R.UDim2,
		Enum = R.Enum,
		Random = Rand,
		task = fakeTask,
		typeof = R.typeof or typeof,
		os = {
			clock = function()
				return now
			end,
			time = function()
				return 86400 * 20000 + math.floor(now)
			end,
		},
		script = scriptStub,
		require = env_require,
	}, { __index = _G })
	-- lune's Model has no PivotTo: move the character by its root part instead.
	env.__pivot = function(model, cframe)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = cframe
		end
	end
	local source = fs.readFile(ROOT .. "/src/server/Systems/OutpostServer.luau")
	source = string.gsub(source, "([%w_%.%(%)]+):PivotTo%(", "__pivot(%1, ")
	-- (and its parts have no Position property: read it from the CFrame)
	source = string.gsub(source, "workspace:GetServerTimeNow%(%)", "__serverNow()")
	env.__serverNow = function()
		return now
	end
	for _, name in { "root", "body", "Probe" } do
		source = string.gsub(source, name .. "%.Position", name .. ".CFrame.Position")
	end
	return luau.load(source, { debugName = "OutpostServer", environment = env })()
end)()
-- ReplicatedStorage:FindFirstChild("Landmarks") in start() goes through the stub above.
Server.start()
local site = Server.site()
check(site and site.Model.Parent == workspaceRoot, "The Outpost wasn't built")
check(#site.Spots >= Rules.NodeCount, "Not enough room for the rocks")
local nodeCount = 0
for _ in Server._nodes do
	nodeCount += 1
end
check(nodeCount == Rules.NodeCount, "Rocks out: " .. nodeCount)
for _, node in Server._nodes do
	local model = node.Model
	check(
		model:GetAttribute("Hp") == Rules.Sizes[node.Size].Hp and model.PrimaryPart ~= nil,
		"A rock without health or a body"
	)
	local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	check(prompt and prompt:GetAttribute("PromptKind") == "Mine", "A rock without its Mine prompt")
	break
end
check(site.Probe:FindFirstChildOfClass("ProximityPrompt") ~= nil, "The Probe has no prompt")
check(
	replicated:FindFirstChild("Landmarks") and replicated.Landmarks:GetAttribute("OutpostSpawn") ~= nil,
	"No way back from a duel"
)

-- Players: an R15-ish body with a root and a right hand.
local function makePlayer(id, name)
	local character = R.Instance.new("Model")
	local root = R.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local hand = R.Instance.new("Part")
	hand.Name = "RightHand"
	hand.Parent = character
	character.PrimaryPart = root
	local p = {
		UserId = id,
		DisplayName = name,
		Character = character,
		Attributes = {},
		CharacterAdded = signal(),
		Changed = {},
	}
	function p:GetAttribute(k)
		return self.Attributes[k]
	end
	function p:SetAttribute(k, v)
		self.Attributes[k] = v
		if self.Changed[k] then
			self.Changed[k]:Fire()
		end
	end
	function p:GetAttributeChangedSignal(k)
		self.Changed[k] = self.Changed[k] or signal()
		return self.Changed[k]
	end
	function p:RequestStreamAroundAsync() end
	profiles[p] = { Coins = 5000 }
	table.insert(playerList, p)
	Players.PlayerAdded:Fire(p)
	return p, root
end
local ana, anaRoot = makePlayer(1, "Ana")
local ben, benRoot = makePlayer(2, "Ben")

check(not handlers.OutpostHit(ana, 1).Ok, "Mined without being at the Outpost")
local entered = handlers.OutpostEnter(ana)
check(entered.Ok and ana:GetAttribute("Outpost") == true, "Couldn't enter the Outpost")
check((anaRoot.CFrame.Position - site.Spawn.Position).Magnitude < 12, "Not brought to the landing pad")
check(
	entered.State.Picks.Survey == Rules.Picks.Survey.Swings and entered.State.Active == "Survey",
	"No free Survey Pick"
)
check(ana.Character:FindFirstChild("OutpostPick") ~= nil, "No pick in hand")
check(
	anaRoot:FindFirstChild("OutpostDuel") and anaRoot:FindFirstChild("OutpostParty"),
	"No duel/party prompts on the miner"
)
handlers.OutpostEnter(ben)

-- Pick a rock and stand by it.
local target
for _, node in Server._nodes do
	if node.Size == "Boulder" then
		target = node
		break
	end
end
target = target or select(2, next(Server._nodes))
local function standBy(root, node)
	root.CFrame = R.CFrame.new(node.Model.PrimaryPart.CFrame.Position + R.Vector3.new(3, 0, 0))
end
check(not handlers.OutpostHit(ana, target.Id).Ok, "Mined from across the basin")
standBy(anaRoot, target)
local first = handlers.OutpostHit(ana, target.Id)
check(first.Ok and first.Hp < target.MaxHp, "A swing didn't chip the rock")
check(first.State.Picks.Survey == Rules.Picks.Survey.Swings - 1, "The swing didn't wear the pick")
check(
	target.Model:GetAttribute("LastHitBy") == 1 and target.Model:GetAttribute("ClaimedBy") == 1,
	"Others can't see who's mining it"
)
check(ana.Character:GetAttribute("ActionKind") == "Heavy", "No chop for others to see")
check(not handlers.OutpostHit(ana, target.Id).Ok, "Swung faster than the pick allows")
-- Ben can't steal it while Ana is on it, but can once she walks away.
standBy(benRoot, target)
advance(0.5)
local stolen = handlers.OutpostHit(ben, target.Id)
check(not stolen.Ok and string.find(stolen.Message, "Ana", 1, true), "Someone else's rock wasn't held for them")
advance(Rules.ClaimSeconds)
check(handlers.OutpostHit(ben, target.Id).Ok, "An abandoned rock couldn't be taken over")
-- Ana takes it back and pops it.
advance(Rules.ClaimSeconds)
local coinsBefore = profiles[ana].Coins
local result
for _ = 1, 40 do
	advance(0.5)
	result = handlers.OutpostHit(ana, target.Id)
	if result.Loot then
		break
	end
end
-- A rock pays coins only by chance now (mining is for gems).
check(result and result.Loot ~= nil, "Popping a rock returned no loot")
check(profiles[ana].Coins == coinsBefore + (result.Loot.Coins or 0), "Coins not paid")
check(Server._nodes[target.Id] == nil and target.Model:GetAttribute("Popped") == 1, "The rock didn't pop")
check(not handlers.OutpostHit(ana, target.Id).Ok, "Mined a popped rock")
check(profiles[ana].Outpost.Rocks == 1, "Rock not counted")
-- It grows back (somewhere) after its respawn time.
local before = 0
for _ in Server._nodes do
	before += 1
end
advance(Rules.Sizes[target.Size].Respawn + 1)
local after = 0
for _ in Server._nodes do
	after += 1
end
check(after == before + 1, "A mined rock never grew back")

-- A pick wears out and breaks; then the Probe sells another.
local nextRock = select(2, next(Server._nodes))
standBy(anaRoot, nextRock)
profiles[ana].Outpost.Picks.Survey = 1
profiles[ana].Outpost.SurveyAt = 86400 * 20000 + math.floor(now) -- (no swings regained meanwhile)
advance(Rules.ClaimSeconds + 1)
local last = handlers.OutpostHit(ana, nextRock.Id)
check(last.Ok and last.PickBroke == "Survey Pick", "The pick didn't break at zero")
advance(1)
local broken = handlers.OutpostHit(ana, nextRock.Id)
check(not broken.Ok and broken.NoPick, "Mined with a broken pick")
check(not handlers.OutpostBuyPick(ana, "Titan").Ok, "Bought a pick away from the Probe")
anaRoot.CFrame = R.CFrame.new(site.Probe.CFrame.Position + R.Vector3.new(0, 0, 6))
local coins = profiles[ana].Coins
local bought = handlers.OutpostBuyPick(ana, "Titan")
check(bought.Ok and profiles[ana].Coins == coins - Rules.Picks.Titan.Price, "Buying a pick didn't charge for it")
check(
	bought.State.Active == "Titan" and bought.State.Picks.Titan == Rules.Picks.Titan.Swings,
	"The bought pick isn't in hand"
)
check(not handlers.OutpostBuyPick(ana, "Survey").Ok, "The free pick was for sale")
profiles[ana].Coins = 10
check(not handlers.OutpostBuyPick(ana, "Plasma").Ok, "Bought a pick without the coins")
-- Time passes: the free pick regains its swings.
profiles[ana].Outpost.Picks.Survey = 0
profiles[ana].Outpost.SurveyAt -= Rules.FreeSwingSeconds * 5
check(handlers.OutpostState(ana).State.Picks.Survey == 5, "The free pick didn't regain swings over time")
profiles[ana].Outpost.SurveyAt -= Rules.FreeSwingSeconds * Rules.Picks.Survey.Swings
check(handlers.OutpostState(ana).State.Picks.Survey == Rules.Picks.Survey.Swings, "The free pick didn't refill")

-- The secrets: six hidden props, each with a prompt; found once for coins.
check(#site.Secrets == #Rules.SecretOrder, "Not every secret was hidden")
check(#site.Parking == 8, "The Motor Pool should have 8 bays")
local secretIds = {}
for _, part in site.Secrets do
	local id = part:GetAttribute("SecretId")
	secretIds[id] = part
	check(Rules.Secrets[id] ~= nil, "A secret with no story: " .. tostring(id))
	check(part:FindFirstChildOfClass("ProximityPrompt") ~= nil, id .. " has no prompt")
	local p = part.CFrame.Position - Rules.Location.Position
	check(R.Vector2.new(p.X, p.Z).Magnitude < 470, id .. " is outside the walls")
end
local duck = secretIds.Duck
anaRoot.CFrame = R.CFrame.new(Rules.Location.Position)
check(not handlers.OutpostSecret(ana, "Duck").Ok, "Found a secret from across the quarry")
check(not handlers.OutpostSecret(ana, "Nope").Ok, "Found a secret that doesn't exist")
anaRoot.CFrame = duck.CFrame * R.CFrame.new(0, 0, 4)
local coinsBefore = profiles[ana].Coins
local announcedBefore = #announced
local first = handlers.OutpostSecret(ana, "Duck")
check(
	first.Ok and first.Secret.New and first.Secret.Found == 1 and first.Secret.Coins == Rules.SecretReward,
	"The first find didn't pay"
)
check(profiles[ana].Coins == coinsBefore + Rules.SecretReward, "Secret coins weren't added")
check(#announced == announcedBefore + 1, "The find wasn't announced")
check(first.State.Secrets == 1 and first.State.SecretsTotal == #Rules.SecretOrder, "The HUD count is wrong")
local again = handlers.OutpostSecret(ana, "Duck")
check(
	again.Ok and not again.Secret.New and profiles[ana].Coins == coinsBefore + Rules.SecretReward,
	"A secret paid twice"
)
-- The full set pays the bonus.
for _, id in Rules.SecretOrder do
	anaRoot.CFrame = secretIds[id].CFrame * R.CFrame.new(0, 0, 4)
	handlers.OutpostSecret(ana, id)
end
check(
	profiles[ana].Coins == coinsBefore + Rules.SecretReward * #Rules.SecretOrder + Rules.SecretBonus,
	"The full-set bonus wasn't paid once"
)

-- Only Ultra Rare and Legendary finds are called out to the server.
local lootCalls = 0
for _, call in announced do
	if string.find(call[2], "unearthed") then
		lootCalls += 1
	end
end
check(gemsAwarded > 0 and lootCalls == 0, "A Rare find was announced to the server")

-- Leaving.
check(handlers.OutpostLeave(ana).Ok and ana:GetAttribute("Outpost") == nil, "Couldn't leave")
check(
	ana.Character:FindFirstChild("OutpostPick") == nil and anaRoot:FindFirstChild("OutpostDuel") == nil,
	"Left with the mining kit on"
)

print(
	"PASS: "
		.. checks
		.. " Outpost checks (rock sizes, swings, claims, pops, loot, respawns, picks wearing out, the Probe, daily pick, secrets, enter/leave)"
)
