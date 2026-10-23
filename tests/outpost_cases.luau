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
	GetTagged = function(_, tag)
		return tags[tag] or {}
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
-- Tasks events (PlayerData.training) by player, e.g. trained[p].Mine.
local trained = {}
local synced = {}
local PlayerData = {
	get = function(p)
		return profiles[p]
	end,
	training = function(p, event)
		trained[p] = trained[p] or {}
		trained[p][event] = (trained[p][event] or 0) + 1
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
	sync = function(p)
		synced[p] = (synced[p] or 0) + 1
	end,
	milestone = function() end,
	count = function() end,
	CharacterChanged = signal(),
}
local gemsAwarded = 0
local lastLuck = nil -- the luck the last gem was rolled with
local Gems = {
	random = function()
		return Rand.new(11)
	end,
	award = function(_, _, opts)
		lastLuck = opts and opts.Luck
		gemsAwarded += 1
		return { Id = "G" .. gemsAwarded, Tier = "Rare", Element = "Shock" }
	end,
}
local MineWall = {
	recoverGear = function()
		return "Test Gear"
	end,
}
-- Who got XP for a rock (Progress.mined: theirs alone, less the more they mine).
local minedBy = {}
local Progress = {
	addXP = function() end,
	mined = function(player)
		table.insert(minedBy, player)
		return 15
	end,
}
local announced = {}
local ChatChannels = {
	announce = function(kind, text)
		table.insert(announced, { kind, text })
	end,
}
local TopPlayers = {
	board = function(name)
		return { { Name = "Ana", Value = if name == "Gear" then 210 else 7, UserId = 7 } }
	end,
	isGlobal = function()
		return false
	end,
}
-- Brutus's bounties (Shared.Bounties): two bosses on one ladder, posters
-- drawn as a label naming each.
local bountyDrawn = {}
local Bounties = {
	Gate = "Bounty",
	Reach = 16,
	Poster = R.Vector2.new(280, 380),
	list = function()
		return { { Biome = "Ashfall", Element = "Fire", Bosses = { { Id = "Drago", Name = "Bombardiro Drago" }, { Id = "SahurTrio", Name = "Sahur Trio" } } } }
	end,
	poster = function(gui, boss)
		local l = R.Instance.new("TextLabel")
		l.Text = boss.Name
		l.Parent = gui
		table.insert(bountyDrawn, boss.Id)
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
		UDim = R.UDim,
		Enum = R.Enum,
		NumberRange = R.NumberRange,
		NumberSequence = R.NumberSequence,
		NumberSequenceKeypoint = R.NumberSequenceKeypoint,
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
-- The sparring rules (Shared.Spar): who's sparring, for the kit and prompts.
local Spar = load("src/shared/Spar.luau", "Spar", {})
-- (its one require, script.Parent.Tags, reads as nil here)
local Tags = load("src/shared/Tags.luau", "Tags", {})
local PickaxeLooks = load(
	"src/shared/PickaxeLooks.luau",
	"PickaxeLooks",
	setmetatable({}, {
		__index = function()
			return Tags
		end,
	})
)

-- The rules ---------------------------------------------------------------------------
-- Ring mixes: the Common Field never grows a Geode, the Crystal Crown never a Pebble.
for i = 0, 999 do
	local roll = i / 1000
	check(Rules.rollSize(roll, "Common") ~= "Geode" and Rules.rollSize(roll, "Common") ~= "Monolith", "Common grew big rock")
	check(Rules.rollSize(roll, "Crystal") ~= "Pebble" and Rules.rollSize(roll, "Crystal") ~= "Boulder", "Crystal grew small rock")
end
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
check(Rules.damage("Survey", false) == 1 and Rules.damage("Survey", true) == 2, "Swing damage wrong")
-- Garrick sells refills (swings, for Robux: each a Store product), not
-- picks; each is cheaper by the swing the bigger it is, and every pick a
-- save held from before turns into swings.
check(#Rules.PickOrder == 1 and Rules.Picks.Survey.Price == 0, "Picks are on sale again")
for i, id in Rules.RefillOrder do
	local refill = Rules.Refills[id]
	check(refill.Swings > 0 and refill.Robux > 0 and type(refill.Product) == "string", id .. " refill incomplete")
	check(refill.Price == nil, id .. " is still sold for coins")
	local before = Rules.Refills[Rules.RefillOrder[i - 1]]
	check(
		not before or refill.Robux / refill.Swings < before.Robux / before.Swings,
		id .. " isn't cheaper by the swing than the smaller refill"
	)
end
check(Rules.Refills.Refill.Swings == Rules.Picks.Survey.Swings, "A Swing Refill isn't a full charge")
-- The free charge is a long session (100+ rocks: your kaiju fights and
-- levels beside you), full again within two hours.
check(Rules.Picks.Survey.Swings / Rules.SwingsPerRock >= 100, "The free charge is under 100 rocks")
check(Rules.Picks.Survey.Swings * Rules.FreeSwingSeconds <= 2 * 3600, "The free pick takes over two hours to fill")
check(Rules.rechargeEvery() == "12 s", "The recharge reads " .. Rules.rechargeEvery())
check(Rules.legacySwings({ Titan = 100, Plasma = 40, Survey = 7 }) == 160, "Old picks didn't turn into swings")
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
	-- As a charge: 10 swings, partway into the next one.
	local into = math.floor(step / 2)
	local swings, nextIn, progress = Rules.surveyCharge(10, 1000, 1000 + into)
	check(swings == 10 and nextIn == step - into and math.abs(progress - into / step) < 1e-9, "Charge reading wrong")
	swings, nextIn, progress = Rules.surveyCharge(10, 1000, 1000 + step * 2 + 1)
	check(swings == 12 and nextIn == step - 1, "Charge didn't count regained swings")
	swings, nextIn, progress = Rules.surveyCharge(full, 0, 999)
	check(swings == full and nextIn == nil and progress == 1, "A full charge still counts down")
	check(
		Rules.clock(102) == "1:42" and Rules.clock(-3) == "0:00" and Rules.clock(7176) == "1:59:36",
		"Clock text wrong"
	)
end
-- Mechs mine: faster than a pick, but every strike spends the swings it
-- lands (never more than you have), so a swing digs the same either way.
for _, id in Rules.MachineOrder do
	local mine = Rules.Machines[id].Mine
	check(mine and mine.Strikes >= 2 and mine.Cooldown > 0, id .. " can't mine")
	check(mine.Strikes / mine.Cooldown > 1 / Rules.SwingCooldown, id .. " mines slower than a pick")
	check(Rules.mechStrikes(id, 100) == mine.Strikes, id .. " strikes the wrong amount")
	check(Rules.mechStrikes(id, 1) == 1 and Rules.mechStrikes(id, 0) == 0, id .. " spends swings you don't have")
end
check(Rules.mechStrikes("NotAMech", 10) == 0 and Rules.mechStrikes(nil, 10) == 0, "Something that isn't a mech mined")
check(Rules.MechReach > Rules.Reach, "A mech reaches less far than a miner")
for _, id in Rules.SizeOrder do
	local s = Rules.Sizes[id]
	check(s.Hp > 0 and s.Respawn > 0 and s.Depth > 0, id .. " rock incomplete")
	-- Mining pays gems only: no rock rolls coins or gear.
	check(
		s.Coins == nil and s.CoinChance == nil and s.Gear == nil and s.Gem == nil,
		id .. " still pays more than a gem"
	)
end

-- The server --------------------------------------------------------------------------
local World = load("src/server/World/OutpostWorld.luau", "OutpostWorld", {})
-- (Its trails come from Shared.Frontier, handed in as the server would find it.)
local Frontier = load("src/shared/Frontier.luau", "Frontier", {})
World.Frontier = Frontier
World.Rules = Rules
-- The Shelter's crew: Builder.vendor's robots, recorded where they're built.
local Vendors = load("src/shared/Vendors.luau", "Vendors", {})
local crewBuilt = {}
local Builder = {
	vendor = function(parent, frame, id, info)
		local model = R.Instance.new("Model")
		model.Name = info.Name
		model.Parent = parent
		table.insert(crewBuilt, { Parent = parent, Frame = frame, Id = id, Info = info })
		return model
	end,
}
-- OutpostServer's requires resolve by name to the stand-ins above.
local Server = (function()
	sharedFolder.Name = "Shared"
	sharedFolder.Parent = replicated
	for _, name in
		{ "Outpost", "Config", "GemConfig", "Mine", "PickaxeLooks", "Spar", "Tutorial", "MechPilot", "Frontier", "SwingRestore", "Vendors", "HallOfFame", "Bounties" }
	do
		local stub = R.Instance.new("Folder")
		stub.Name = name
		stub.Parent = sharedFolder
	end
	local env_require = function(m)
		local key = if type(m) == "table" then m.__name elseif typeof(m) == "Instance" then m.Name else nil
		if key then
			return ({
				Outpost = Rules,
				Frontier = Frontier,
				Config = { MaxGems = 200 },
				GemConfig = GemConfig,
				Mine = Mine,
				PickaxeLooks = PickaxeLooks,
				Spar = Spar,
				Tutorial = { beat = function() return nil end }, -- (no mining tutorial running)
				MechPilot = load("src/shared/MechPilot.luau", "MechPilot", {}),
				SwingRestore = load("src/shared/SwingRestore.luau", "SwingRestore", {}),
				Vendors = Vendors,
				HallOfFame = load("src/shared/HallOfFame.luau", "HallOfFame", {}),
				Bounties = Bounties,
				Builder = Builder,
				Intro = { tutorialMined = function() return nil end },
				OutpostWorld = World,
				Gems = Gems,
				ChatChannels = ChatChannels,
				MineWall = MineWall,
				MiningRolls = { publish = function() end },
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
	for _, name in { "root", "body" } do
		source = string.gsub(source, name .. "%.Position", name .. ".CFrame.Position")
	end
	return luau.load(source, { debugName = "OutpostServer", environment = env })()
end)()
-- ReplicatedStorage:FindFirstChild("Landmarks") in start() goes through the stub above.
Server.start()
local site = Server.site()
check(site and site.Model.Parent == workspaceRoot, "The Outpost wasn't built")
-- Every spot holds a rock: the field round the middle, the outcrops out to
-- the walls and the three Rift Veins (Shared.Frontier).
check(#site.Spots >= 170 and #site.Spots <= Rules.NodeCount, "Not enough room for the rocks: " .. #site.Spots)
check(#site.OutcropSpots >= 90 and #site.Veins == 3 and #site.Scars == 3, "The outcrops or veins are missing")
-- The Skyport: compact, every spot on a mining ring, each ring with room.
do
	local perZone = {}
	local centre = Rules.Location.Position
	for i, spot in site.Spots do
		local zone = site.Zones[i]
		check(Rules.Zones[zone] ~= nil, "A rock spot off the rings: " .. tostring(zone))
		perZone[zone] = (perZone[zone] or 0) + 1
		local offset = spot.Position - centre
		check(
			R.Vector3.new(offset.X, 0, offset.Z).Magnitude < Rules.Radius,
			"A rock spot off the island"
		)
	end
	-- Each ring the lobby grows rocks on has room (the Field ring only while
	-- it has rocks of its own: FieldNodeCount 0 keeps everyone on the quarry).
	for _, zone in Rules.ZoneOrder do
		if zone ~= "Field" or Rules.FieldNodeCount > 0 then
			check((perZone[zone] or 0) >= 8, zone .. " ring has too little room: " .. tostring(perZone[zone]))
		end
	end
end
local nodeCount = 0
for _ in Server._nodes do
	nodeCount += 1
end
check(nodeCount == math.min(Rules.NodeCount, #site.Spots), "Rocks out: " .. nodeCount)
for _, node in Server._nodes do
	-- A ring only grows its own mix.
	local zone = site.Zones[node.Spot]
	check((Rules.Zones[zone].Weights[node.Size] or 0) > 0, node.Size .. " grew on the " .. zone .. " ring")
	local model = node.Model
	check(
		model:GetAttribute("Hp") == Rules.Sizes[node.Size].Hp and model.PrimaryPart ~= nil,
		"A rock without health or a body"
	)
	local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	check(prompt and prompt:GetAttribute("PromptKind") == "Mine", "A rock without its Mine prompt")
	break
end
-- Further out the crystals glow in their band's colour (a Rift Vein's
-- violet), and each rock says its zone for the client.
do
	local tints = {}
	for _, node in Server._nodes do
		local zone = site.Zones[node.Spot]
		check(node.Zone == zone and node.Model:GetAttribute("Zone") == zone, "A rock doesn't know its zone")
		local crystal
		for _, d in node.Model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Crystal" then
				crystal = d
				break
			end
		end
		if crystal and Frontier.Bands[zone] then
			check(crystal.Color == Frontier.Bands[zone].Color, zone .. " crystals aren't its colour")
			tints[zone] = true
		end
	end
	check(tints.Fringe and tints.Edge and tints.Vein, "Some band's rocks never grew")
	-- Each vein's dormant rift, by the walls, facing in.
	for _, scar in site.Scars do
		local offset = scar.Position - Rules.Location.Position
		check(R.Vector3.new(offset.X, 0, offset.Z).Magnitude > Frontier.Rim - 1, "A rift scar off the walls")
	end
	-- No glowing cracks on the ground round the outcrops, no crumb roads,
	-- and each vein's marks.
	check(site.Model:FindFirstChild("Frontier") == nil, "The glowing cracks round the outcrops are back")
	check(site.Model:FindFirstChild("Trails") == nil, "The old trails are still there")
	local marks = site.Model:FindFirstChild("Veins")
	check(marks and #marks:GetChildren() == 3, "The veins have no marks")
	for _, model in marks:GetChildren() do
		-- (No beam of light over it any more: its Rift Gate, the way in.)
		check(model:FindFirstChild("VeinBeam") == nil, "A vein's beam of light is back")
		local gate = model:FindFirstChild("RiftGate")
		local heart = gate and gate:FindFirstChild("Heart")
		local prompt = heart and heart:FindFirstChildOfClass("ProximityPrompt")
		check(prompt and prompt:GetAttribute("PromptKind") == "Rift" and prompt.ActionText == "Enter the Rift", "A vein without its Rift Gate")
		local shards = 0
		for _, piece in gate:GetChildren() do
			if piece:IsA("BasePart") and piece.Material == R.Enum.Material.Slate then
				shards += 1
			end
		end
		check(shards >= 12, "The gate's arch is missing its rock")
		check(heart:FindFirstChildOfClass("PointLight") and heart:FindFirstChildOfClass("ParticleEmitter"), "The gate has no glow or embers")
	end
end
-- (No PROBE-7 and no duel gate: Garrick sells the refills, Brutus is
-- behind his bounty counter, below.)
check(site.Probe == nil and site.Gate == nil and Vendors.Probe == nil, "PROBE-7 or a duel gate is back")
for _, d in site.Model:GetDescendants() do
	local kind = d.ClassName == "ProximityPrompt" and d:GetAttribute("PromptKind")
	check(kind ~= "Probe" and kind ~= "Gate", "A Probe or Gate prompt is back")
	check(not (d:IsA("TextLabel") and string.find(d.Text, "PROBE", 1, true)), "PROBE-7 is still named in the Shelter")
end
-- Brutus's bounty booth: its terminal opens the bounty board (Client.
-- RiftClient: every Rift boss), and a WANTED poster for each boss.
do
	local counter = site.Bounty and site.Bounty.Counter
	local prompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")
	check(prompt and prompt:GetAttribute("PromptKind") == "Bounty", "Brutus's counter has no Bounty prompt")
	check(Server.bountyCounter() == counter, "The Rift doesn't know where Brutus's counter is")
	check(#site.Bounty.Posters >= 10, "Not a poster for every Rift boss: " .. #site.Bounty.Posters)
	check(table.concat(bountyDrawn, ",") == "Drago,SahurTrio", "The posters aren't the bounties, in order")
	local poster = site.Bounty.Posters[1]:FindFirstChildOfClass("SurfaceGui")
	check(poster and poster:FindFirstChildOfClass("TextLabel").Text == "Bombardiro Drago", "The first poster isn't drawn")
	check(site.Bounty.Posters[3]:FindFirstChildOfClass("SurfaceGui") == nil, "A poster for a boss that isn't there")
end
-- Brutus's duel booth: its terminal opens the duel queue (Client.
-- OutpostScene: SocialUI's Arena), a prompt of its own, on the south wall
-- by the bounty office.
do
	local counter = site.Duel and site.Duel.Counter
	local prompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")
	check(prompt and prompt:GetAttribute("PromptKind") == "Duels", "Brutus's counter has no Duels prompt")
	check((counter.CFrame.Position - site.Bounty.Counter.CFrame.Position).Magnitude > 20, "The duel booth sits on the bounty office")
	local scene = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
	check(scene:find('kind == "Duels"', 1, true) ~= nil, "The client doesn't open the duel queue from Brutus's counter")
end
-- The Hall of Fame: the board on the east wall, its five columns from
-- TopPlayers (Shared.HallOfFame).
do
	Server._drawBoard()
	local gui = site.Board:FindFirstChild("Board")
	check(gui and gui.CanvasSize == R.Vector2.new(1600, 760), "The Hall of Fame isn't drawn on the board")
	local texts = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") then
			texts[d.Text] = (texts[d.Text] or 0) + 1
		end
	end
	check(texts["HALL OF FAME"] == 1 and texts["PVP HALL OF FAME"] == 1 and texts["PVE HALL OF FAME"] == 1, "The halls' titles")
	for _, title in { "1V1 DUELS", "1V1 + KAIJU", "KAIJU BATTLES", "BOUNTY HUNTERS", "TOP MINERS" } do
		check(texts[title] == 1, "No " .. title .. " column")
	end
	check(texts.Ana == 5 and texts.UNCLAIMED == nil, "Each column's champion isn't the board's first")
	local children = #gui:GetDescendants()
	Server._drawBoard()
	check(#gui:GetDescendants() == children, "The board was drawn twice over")
	local headshot = gui:FindFirstChild("Headshot", true)
	check(headshot and string.find(headshot.Image, "id=7", 1, true), "The champion's face isn't theirs")
end
-- The Shelter's Store and Market counters open those screens (OutpostScene).
for kind, counter in { Store = site.Stations.Store, Market = site.Stations.Market } do
	local prompt = counter:FindFirstChildOfClass("ProximityPrompt")
	check(prompt and prompt:GetAttribute("PromptKind") == kind, "The Shelter's " .. kind .. " has no prompt")
end
-- The Shelter's crew: the old town's shopkeepers and INFO-9, the info rep,
-- each built where the Shelter puts them, on its floor (up on its legs),
-- in its hall (south of the garage's barrier), clear of each other, the
-- counters and where players arrive. Garrick sells refills and Brutus
-- shows the bounties, first thing they offer (Brutus from behind his
-- counter). Every line they
-- offer is a reply, an action the dialogue knows, or a topic of those; and
-- every one of INFO-9's lines and tips is in the Spanish table.
do
	local OG = {
		GemBuyer = "Ilsa",
		ArenaMaster = "Brutus",
		Broker = "Tamsin",
		Outfitter = "Borin",
		Foreman = "Garrick",
		InfoBot = "INFO-9",
		BountyClerk = "Marlo",
	}
	check(#crewBuilt == 7 and #site.Crew == 7, "The Shelter's crew isn't all there: " .. #crewBuilt)
	check(Vendors.Foreman.Options[1].Action == "Exchange", "Garrick doesn't sell the refills first")
	check(Vendors.ArenaMaster.Options[1].Action == "Duels", "Brutus doesn't set up a duel first")
	check(Vendors.BountyClerk.Options[1].Action == "Bounties", "Marlo doesn't show the bounties first")
	for _, built in crewBuilt do
		if built.Id == "ArenaMaster" then
			check((built.Frame.Position - site.Duel.Counter.CFrame.Position).Magnitude < 10, "Brutus isn't at his duel counter")
		elseif built.Id == "BountyClerk" then
			check((built.Frame.Position - site.Bounty.Counter.CFrame.Position).Magnitude < 10, "Marlo isn't at the bounty counter")
		end
	end
	local dialogue = fs.readFile(ROOT .. "/src/client/Dialogue.client.luau")
	local function flat(p)
		local q = p - Rules.Location.Position
		return R.Vector3.new(q.X, 0, q.Z)
	end
	local box = site.Shelter.Box
	local keep = {
		{ flat(site.Spawn.Position), 9, "where players arrive" },
		{ flat(site.Stations.Store.CFrame.Position), 9, "the Store's counter" },
		{ flat(site.Stations.Market.CFrame.Position), 9, "the Market's counter" },
	}
	for i, built in crewBuilt do
		local info = Vendors[built.Id]
		check(info and built.Info == info and info.Name == OG[built.Id], "A crew member who isn't the OG one: " .. built.Id)
		check(built.Parent.Name == "Crew" and built.Parent.Parent == site.Model, built.Id .. " isn't in the Outpost's Crew")
		local p = flat(built.Frame.Position)
		check(math.abs(p.X) < box.X - 8 and p.Z > -14 and p.Z < box.Y - 8, built.Id .. " stands outside the Shelter's hall")
		check(
			math.abs(built.Frame.Position.Y - (Rules.Location.Position.Y + Rules.ShelterLift + 0.86)) < 0.01,
			built.Id .. " isn't on the floor"
		)
		for _, k in keep do
			check((p - k[1]).Magnitude >= k[2], built.Id .. " stands on " .. k[3])
		end
		for j = i + 1, #crewBuilt do
			check((p - flat(crewBuilt[j].Frame.Position)).Magnitude > 12, built.Id .. " stands on top of " .. crewBuilt[j].Id)
		end
		local function walk(options, topic)
			for _, option in options do
				local kinds = (if option.Reply then 1 else 0)
					+ (if option.Action then 1 else 0)
					+ (if option.Options then 1 else 0)
				check(kinds == 1, built.Id .. "'s option needs a reply, an action or a topic: " .. option.Text)
				check(not (topic and option.Options), built.Id .. "'s topic has a topic in it: " .. option.Text)
				if option.Action then
					check(
						string.find(dialogue, "function actions." .. option.Action .. "()", 1, true) ~= nil,
						"The dialogue can't do " .. built.Id .. "'s " .. option.Action
					)
				end
				if option.Options then
					-- (with Back, a topic fits the dialogue's five rows)
					check(
						#option.Options >= 1 and #option.Options <= 4,
						built.Id .. "'s topic is too long: " .. option.Text
					)
					walk(option.Options, true)
				end
			end
		end
		check(#info.Options <= 4, built.Id .. " offers too many options for the dialogue's five rows")
		walk(info.Options, false)
	end
	local Lang = load("src/shared/Lang.luau", "Lang", {})
	local LangEs = load("src/shared/LangEs.luau", "LangEs", {})
	local function spanish(text)
		check(LangEs[(Lang.normalize(text))] ~= nil, "No Spanish for INFO-9's " .. text)
	end
	local bot = Vendors.InfoBot
	spanish(bot.Greeting)
	spanish(string.upper(bot.Name .. " // " .. bot.Role))
	spanish(bot.Name .. ", " .. bot.Role)
	spanish("What would you like to know?")
	spanish("Back")
	local function lines(options)
		for _, option in options do
			spanish(option.Text)
			if option.Reply then
				spanish(option.Reply)
			end
			lines(option.Options or {})
		end
	end
	lines(bot.Options)
	check(#Vendors.Tips >= 10, "INFO-9 is short of tips")
	for _, tip in Vendors.Tips do
		spanish(tip)
	end
	-- COACH-4, the Kaiju Arena's guide downstairs (Server.KaijuPitServer
	-- builds it): the same shape of dialogue, its tips, all in Spanish.
	local coach = Vendors.ArenaGuide
	check(coach and coach.Name == "COACH-4", "No guide for the Kaiju Arena")
	check(#coach.Options <= 4, "COACH-4 offers too many options for the dialogue's five rows")
	local function walkCoach(options, topic)
		for _, option in options do
			local kinds = (if option.Reply then 1 else 0)
				+ (if option.Action then 1 else 0)
				+ (if option.Options then 1 else 0)
			check(kinds == 1, "COACH-4's option needs a reply, an action or a topic: " .. option.Text)
			check(not (topic and option.Options), "COACH-4's topic has a topic in it: " .. option.Text)
			if option.Action then
				check(
					string.find(dialogue, "function actions." .. option.Action .. "()", 1, true) ~= nil,
					"The dialogue can't do COACH-4's " .. option.Action
				)
			end
			if option.Options then
				check(#option.Options >= 1 and #option.Options <= 4, "COACH-4's topic is too long: " .. option.Text)
				walkCoach(option.Options, true)
			end
		end
	end
	walkCoach(coach.Options, false)
	spanish(coach.Greeting)
	spanish(string.upper(coach.Name .. " // " .. coach.Role))
	spanish(coach.Name .. ", " .. coach.Role)
	lines(coach.Options)
	check(#Vendors.ArenaTips >= 10, "COACH-4 is short of tips")
	for _, tip in Vendors.ArenaTips do
		spanish(tip)
	end
end
-- Players arrive inside the Shelter, its mechs parked in the garage.
do
	local box = site.Shelter.Box
	local p = site.Spawn.Position - Rules.Location.Position
	check(math.abs(p.X) < box.X and math.abs(p.Z) < box.Y, "Players don't arrive in the Shelter")
	for _, bay in site.Parking do
		local q = bay.CFrame.Position - Rules.Location.Position
		check(math.abs(q.X) < box.X and math.abs(q.Z) < box.Y, "A mech bay outside the Shelter's garage")
	end
	-- They arrive facing a Mole drill: one parked straight ahead, close.
	local ahead = false
	for _, bay in site.Parking do
		local to = bay.CFrame.Position - site.Spawn.Position
		to = R.Vector3.new(to.X, 0, to.Z)
		if bay.Kind == "Mole" and to.Magnitude < 34 and to.Unit:Dot(site.Spawn.LookVector) > 0.97 then
			ahead = true
		end
	end
	check(ahead, "Players don't arrive facing a mech")
end
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
check(ana.Character.OutpostPick:GetAttribute("PickSkin") == nil, "A pick skin nobody wears")
-- A pickaxe skin goes into the hand as soon as it's put on, and comes off.
profiles[ana].Cosmetics = { Owned = { PickStorm = true }, Pick = "PickStorm" }
PlayerData.CharacterChanged:Fire(ana)
local skinned = ana.Character:FindFirstChild("OutpostPick")
check(skinned and skinned:GetAttribute("PickSkin") == "PickStorm", "A pickaxe skin didn't go into the hand")
check(skinned:FindFirstChild("PickTip") and #skinned:GetChildren() > 10, "The skinned pick wasn't built")
profiles[ana].Cosmetics.Pick = "PickVoid" -- (not owned)
PlayerData.CharacterChanged:Fire(ana)
check(ana.Character.OutpostPick:GetAttribute("PickSkin") == nil, "A pick skin not owned was put in the hand")
profiles[ana].Cosmetics = nil
check(
	anaRoot:FindFirstChild("OutpostDuel") and anaRoot:FindFirstChild("OutpostParty"),
	"No duel/party prompts on the miner"
)
-- Drawn by the client as one card beside the miner (PlayerCard): no panels of
-- Roblox's own stacked over them, and each its own key and gamepad button.
local keys, pads = {}, {}
for _, name in { "OutpostSpar", "OutpostDuel", "OutpostParty", "OutpostKaiju" } do
	local prompt = anaRoot:FindFirstChild(name)
	check(prompt and prompt.Style == R.Enum.ProximityPromptStyle.Custom, name .. " is drawn by Roblox, not the card")
	check(prompt.UIOffset == R.Vector2.zero, name .. " is still stacked over the miner")
	check(prompt:GetAttribute("TargetUserId") == ana.UserId, name .. " doesn't say whose it is")
	keys[prompt.KeyboardKeyCode], pads[prompt.GamepadKeyCode] = true, true
end
local function size(set)
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end
check(size(keys) == 4 and size(pads) == 4, "Two social prompts share a key or gamepad button")
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
local syncsBefore = synced[ana] or 0
-- (Every swing makes noise for the frontier: OutpostServer.onSwing.)
local swingsHeard = {}
Server.onSwing = function(player, swings)
	table.insert(swingsHeard, { player, swings })
end
local first = handlers.OutpostHit(ana, target.Id)
check(#swingsHeard == 1 and swingsHeard[1][1] == ana and swingsHeard[1][2] == 1, "A swing made no noise")
check(first.Ok and first.Hp < target.MaxHp, "A swing didn't chip the rock")
-- (The reply carries the swing: a whole profile sync per swing was heavy.)
check((synced[ana] or 0) == syncsBefore, "A swing that didn't pop the rock synced the whole profile")
check(first.State.Picks.Survey == Rules.Picks.Survey.Swings - 1, "The swing didn't wear the pick")
check(
	first.State.SurveyAt ~= nil and first.State.NextSwingIn == Rules.FreeSwingSeconds,
	"The HUD didn't get the charge clock"
)
check(
	target.Model:GetAttribute("LastHitBy") == 1 and target.Model:GetAttribute("ClaimedBy") == 1,
	"Others can't see who's mining it"
)
check(ana.Character:GetAttribute("ActionKind") == "Mine", "No chop for others to see")
check(not handlers.OutpostHit(ana, target.Id).Ok, "Swung faster than the pick allows")
-- From a mech's cockpit (its pilot: Shared.MechPilot, no seat): from
-- further off, a strike lands several swings at once and spends them, and
-- the mech swings for everyone to see.
do
	local mech = R.Instance.new("Model")
	mech.Name = "Mole"
	mech:SetAttribute("MechId", "Mole3")
	mech:SetAttribute("MechKind", "Mole")
	mech.Parent = workspaceRoot
	CollectionService:AddTag(mech, "OutpostMech")
	ana:SetAttribute("MechPilot", "Mole3")
	advance(1)
	local swingsBefore, hpBefore = first.State.Picks.Survey, target.Hp
	local rock = target.Model.PrimaryPart.CFrame.Position
	anaRoot.CFrame = R.CFrame.new(rock + R.Vector3.new(Rules.MechReach - 2, 9, 0))
	local strike = handlers.OutpostHit(ana, target.Id)
	local strikes = Rules.Machines.Mole.Mine.Strikes
	check(strike.Ok and strike.Strikes == strikes, "A mech couldn't mine: " .. tostring(strike.Message))
	check(swingsHeard[#swingsHeard][2] == strikes, "A mech's strike made one swing's noise")
	check(strike.State.Picks.Survey == swingsBefore - strikes, "A mech strike didn't spend its swings")
	check(hpBefore - strike.Hp >= strikes, "A mech strike didn't land its swings")
	check(
		type(mech:GetAttribute("MechStrikeStart")) == "number" and typeof(mech:GetAttribute("MechStrikeTarget")) == "Vector3",
		"Nobody sees the mech strike"
	)
	anaRoot.CFrame = R.CFrame.new(rock + R.Vector3.new(Rules.MechReach + 30, 9, 0))
	advance(1)
	check(not handlers.OutpostHit(ana, target.Id).Ok, "A mech mined from too far off")
	mech:SetAttribute("MechKind", "NotAMech")
	standBy(anaRoot, target)
	advance(1)
	local refused = handlers.OutpostHit(ana, target.Id)
	check(not refused.Ok and refused.Message:find("Hop out", 1, true), "Mined from a machine that can't mine")
	ana:SetAttribute("MechPilot", nil)
	mech.Parent = nil
end
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
local syncsBeforePop = synced[ana] or 0
local gemsBeforePop = gemsAwarded
table.clear(minedBy)
local result
for _ = 1, 40 do
	advance(0.5)
	result = handlers.OutpostHit(ana, target.Id)
	if result.Loot then
		break
	end
end
-- A rock pays one gem, every time, and nothing else (mining is for gems).
check(result and result.Loot ~= nil, "Popping a rock returned no loot")
check((synced[ana] or 0) == syncsBeforePop + 1, "A pop didn't sync the profile once (only the pop sends it)")
check(result.Loot.Gem ~= nil and gemsAwarded == gemsBeforePop + 1, "A popped rock didn't pay exactly one gem")
check(result.Loot.Coins == nil and result.Loot.Gear == nil, "A popped rock paid coins or gear")
check(profiles[ana].Coins == coinsBefore, "Mining paid coins")
check(Server._nodes[target.Id] == nil and target.Model:GetAttribute("Popped") == 1, "The rock didn't pop")
check(not handlers.OutpostHit(ana, target.Id).Ok, "Mined a popped rock")
check(profiles[ana].Outpost.Rocks == 1, "Rock not counted")
-- XP for her (Progress.mined), once; nothing for her kaiju (no hook to them).
check(#minedBy == 1 and minedBy[1] == ana, "A popped rock didn't give its miner XP once")
check(Server.onRockMined == nil, "A rock still reaches your kaiju")
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
local regrown
for _, node in Server._nodes do
	if node.Spot == target.Spot then
		regrown = node
	end
end
check(regrown and regrown.Zone == target.Zone, "A mined rock grew back somewhere else")
-- Further out, luckier: a gem from a Rift Vein boulder rolls with its zone's
-- luck on top of the boulder's own.
local commonLuck = lastLuck
local vein
for _, node in Server._nodes do
	if node.Zone == "Vein" and node.Size == target.Size then
		vein = node
		break
	end
end
check(vein ~= nil, "No boulder in a Rift Vein")
if vein then
	standBy(anaRoot, vein)
	for _ = 1, 40 do
		advance(0.5)
		local hit = handlers.OutpostHit(ana, vein.Id)
		if hit.Loot then
			check(hit.Loot.Zone == "Vein", "The loot doesn't say where it came from")
			break
		end
	end
	check(
		math.abs(lastLuck - commonLuck - (Rules.Zones.Vein.Luck - (Rules.Zones[target.Zone].Luck or 0))) < 1e-9,
		string.format(
			"A vein's gem rolled with %s luck (a %s rock's %s)",
			tostring(lastLuck),
			target.Zone,
			tostring(commonLuck)
		)
	)
end

-- Rift Charged (a wandering rift cleared): gems roll luckier while it lasts.
do
	local plain
	for _, node in Server._nodes do
		if node.Zone == target.Zone and node.Size == target.Size and node ~= vein then
			plain = node
			break
		end
	end
	check(plain ~= nil, "No rock like the first to mine Rift Charged")
	ana:SetAttribute("RiftCharged", now + 30)
	standBy(anaRoot, plain)
	advance(Rules.ClaimSeconds + 1)
	for _ = 1, 40 do
		advance(0.5)
		if handlers.OutpostHit(ana, plain.Id).Loot then
			break
		end
	end
	check(math.abs(lastLuck - commonLuck - Frontier.Charged.Luck) < 1e-9, "Rift Charged didn't add its luck")
	ana:SetAttribute("RiftCharged", nil)
	-- A patch a wild pack holds (Kaiju.Wild.Claim, KaijuWilds): every swing
	-- at a rock reaches the pack (its spot's position), and its gems roll
	-- luckier by what the pack's rules say.
	local held
	for _, node in Server._nodes do
		if node.Zone == target.Zone and node.Size == target.Size and node ~= vein and node ~= plain then
			held = node
			break
		end
	end
	check(held ~= nil, "No rock like the first for a pack to hold")
	local swungAt = {}
	Server.onRockSwing = function(position, player)
		table.insert(swungAt, { position, player })
	end
	Server.patchLuck = function(position)
		return if (position - site.Spots[held.Spot].Position).Magnitude < 1 then 0.08 else 0
	end
	standBy(anaRoot, held)
	advance(Rules.ClaimSeconds + 1)
	for _ = 1, 40 do
		advance(0.5)
		if handlers.OutpostHit(ana, held.Id).Loot then
			break
		end
	end
	check(#swungAt > 0 and swungAt[1][2] == ana, "A swing didn't reach the patch's pack")
	check(
		swungAt[1][1] and (swungAt[1][1] - site.Spots[held.Spot].Position).Magnitude < 1,
		"The swing reached the pack with the wrong rock"
	)
	check(math.abs(lastLuck - commonLuck - 0.08) < 1e-9, "A held patch's luck didn't land on the gem")
	Server.onRockSwing = function() end
	Server.patchLuck = function()
		return 0
	end
end

-- The pick's bonk on a rift's critter (KaijuWilds does the blow): close, on
-- foot, the swing's cooldown, never a swing spent.
do
	local critterModel = R.Instance.new("Model")
	local enemy = { Alive = true, Root = { Position = anaRoot.CFrame.Position + R.Vector3.new(4, 0, 0) } }
	local bonks = {}
	check(not handlers.OutpostBonk(ana, critterModel).Ok, "Bonked with no frontier running")
	Server.bonker = {
		critterOf = function(model)
			return if model == critterModel then enemy else nil
		end,
		bonk = function(target, player, from)
			table.insert(bonks, { target, player, from })
			return true
		end,
	}
	advance(1)
	local picksBefore = profiles[ana].Outpost.Picks.Survey
	local hit = handlers.OutpostBonk(ana, critterModel)
	check(hit.Ok and hit.Bonk and #bonks == 1 and bonks[1][1] == enemy and bonks[1][2] == ana, "The bonk didn't land")
	check(profiles[ana].Outpost.Picks.Survey == picksBefore, "A bonk spent a swing")
	check(not handlers.OutpostBonk(ana, critterModel).Ok and #bonks == 1, "Bonked again without the cooldown")
	advance(Frontier.Bonk.Cooldown + 0.05)
	check(handlers.OutpostBonk(ana, critterModel).Ok and #bonks == 2, "No second bonk after the cooldown")
	advance(1)
	check(not handlers.OutpostBonk(ana, R.Instance.new("Model")).Ok, "Bonked something that isn't a critter")
	enemy.Root.Position = anaRoot.CFrame.Position + R.Vector3.new(Frontier.Bonk.Reach + 6, 0, 0)
	local far = handlers.OutpostBonk(ana, critterModel)
	check(not far.Ok and far.Message:find("closer", 1, true), "Bonked from afar")
	enemy.Root.Position = anaRoot.CFrame.Position + R.Vector3.new(3, 0, 0)
	ana:SetAttribute("MechPilot", "Mole3")
	advance(1)
	check(not handlers.OutpostBonk(ana, critterModel).Ok, "Bonked from a mech's cockpit")
	ana:SetAttribute("MechPilot", nil)
	enemy.Alive = false
	advance(1)
	check(not handlers.OutpostBonk(ana, critterModel).Ok, "Bonked a dead critter")
	Server.bonker = nil
end

-- Rift Veins move: once mined out (a moment after its last rock pops), and
-- in time anyway (put off while someone's mining it). Fresh rocks at the
-- new site, away from the other two; its marks and dormant rift move; word
-- goes round.
do
	local veins = Server._veins
	check(#veins == 3, "The server isn't keeping the veins")
	local moved, swungAt = {}, {}
	Server.onVeinMoved = function(index, scar)
		table.insert(moved, { index, scar })
	end
	Server.onVeinSwing = function(index, player)
		table.insert(swungAt, { index, player })
	end
	local function siteOf(v)
		return site.VeinSites[veins[v].Site]
	end
	local function nodesOn(v)
		local list = {}
		for _, spot in veins[v].Spots do
			for _, node in Server._nodes do
				if node.Spot == spot then
					table.insert(list, node)
				end
			end
		end
		return list
	end
	check(#nodesOn(1) == Frontier.Veins.Rocks, "A vein isn't fully grown")
	-- One is guarded: luckier rocks of its own zone, and its gate's cracks
	-- its colour; each gate's prompt says which vein it is.
	local guarded = Frontier.Veins.Guarded
	local function crackOf(v)
		return veins[v].Marks and veins[v].Marks:FindFirstChild("ScarCrack")
	end
	local function gatePrompt(v)
		local gate = veins[v].Marks and veins[v].Marks:FindFirstChild("RiftGate")
		local heart = gate and gate:FindFirstChild("Heart")
		return heart and heart:FindFirstChildOfClass("ProximityPrompt")
	end
	local function sameColor(x, y)
		return math.abs(x.R - y.R) + math.abs(x.G - y.G) + math.abs(x.B - y.B) < 0.01
	end
	for v = 1, 3 do
		local zone = if v == guarded then "Guarded" else "Vein"
		for _, node in nodesOn(v) do
			check(node.Zone == zone, "A vein " .. v .. " rock in the " .. tostring(node.Zone) .. " zone")
		end
		local crack = crackOf(v)
		if v == guarded then
			check(crack and sameColor(crack.Color, Frontier.Bands.Guarded.Color), "The guarded vein's gate isn't its colour")
		else
			check(crack and not sameColor(crack.Color, Frontier.Bands.Guarded.Color), "A plain vein's gate in the guarded colour")
		end
		check(gatePrompt(v) and gatePrompt(v):GetAttribute("Vein") == v, "Vein " .. v .. "'s gate doesn't say which vein it is")
	end
	-- Mine it out.
	local before = siteOf(1)
	profiles[ana].Outpost.Picks.Survey = 500
	profiles[ana].Gems = {}
	for _, node in nodesOn(1) do
		standBy(anaRoot, node)
		advance(Rules.ClaimSeconds + 1)
		local last
		for _ = 1, 60 do
			advance(0.4)
			last = handlers.OutpostHit(ana, node.Id)
			if last.Loot then
				break
			end
		end
	end
	check(#nodesOn(1) == 0, "Couldn't mine the vein out (or its rocks grew back in place)")
	check(#swungAt > 0 and swungAt[1][1] == 1 and swungAt[1][2] == ana, "Its guardian never heard the swings")
	advance(5)
	check(#moved == 1 and moved[1][1] == 1, "A mined-out vein didn't move")
	local after = siteOf(1)
	check(after ~= before, "It surfaced where it was")
	check(#nodesOn(1) == Frontier.Veins.Rocks, "The moved vein has no fresh rocks")
	for k, spot in veins[1].Spots do
		check((site.Spots[spot].Position - after.Rocks[k].Position).Magnitude < 1e-3, "A vein rock off its new site")
	end
	for v = 2, 3 do
		check(Frontier.apart(after.Angle, siteOf(v).Angle) >= Frontier.Veins.Apart, "It surfaced beside another vein")
	end
	check((moved[1][2].Position - after.Scar.Position).Magnitude < 1e-3, "Its dormant rift didn't move with it")
	local news = workspaceRoot:GetAttribute("VeinNews") or ""
	check(string.find(news, Frontier.compass(after.Angle), 1, true), "No word of where it went")
	check(string.find(news, "A guarded Rift Vein", 1, true) == (if guarded == 1 then 1 else nil), "The news")
	local red = crackOf(guarded)
	check(red and sameColor(red.Color, Frontier.Bands.Guarded.Color), "Moved, its gate isn't the guarded colour")
	check(gatePrompt(1) and gatePrompt(1):GetAttribute("Vein") == 1, "Moved, its gate went without it")
	-- Nothing grows back on top of the new rocks.
	local count = #nodesOn(1)
	advance(400)
	check(#nodesOn(1) == count, "A rock grew back on top of the moved vein")
	-- In time, anyway, but not while someone's mining it.
	local node2 = nodesOn(2)[1]
	standBy(anaRoot, node2)
	advance(Rules.ClaimSeconds + 1)
	handlers.OutpostHit(ana, node2.Id)
	local site2 = veins[2].Site
	veins[2].Due = now
	Server._veinTick(now)
	check(veins[2].Site == site2 and veins[2].Due > now, "A vein moved from under its miner")
	advance(Rules.ClaimSeconds + 1)
	veins[2].Due = now
	Server._veinTick(now)
	check(veins[2].Site ~= site2 and #moved == 2 and moved[2][1] == 2, "A vein never moved in time")
	local plain = workspaceRoot:GetAttribute("VeinNews") or ""
	check(string.find(plain, "A Rift Vein surfaced", 1, true) == 1, "A plain vein's news: " .. plain)
	check(veins[2].Due - now >= Frontier.Veins.Every - Frontier.Veins.Wobble - 1, "Its next move isn't ten minutes off")
	profiles[ana].Gems = {}
end

-- A full gem pouch: no swinging (the rock would pay a gem with nowhere to
-- go), and the pick isn't worn by trying.
local nextRock = select(2, next(Server._nodes))
standBy(anaRoot, nextRock)
advance(Rules.ClaimSeconds + 1)
profiles[ana].Gems = table.create(200, {})
local swingsBefore = profiles[ana].Outpost.Picks[profiles[ana].Outpost.Active]
local full = handlers.OutpostHit(ana, nextRock.Id)
check(not full.Ok and full.PouchFull and string.find(full.Message, "full", 1, true), "Mined with a full gem pouch")
check(profiles[ana].Outpost.Picks[profiles[ana].Outpost.Active] == swingsBefore, "A refused swing wore the pick")
check(nextRock.Hp == nextRock.MaxHp, "A refused swing chipped the rock")
profiles[ana].Gems = nil

-- A pick wears out and breaks; then Garrick sells refills.
profiles[ana].Outpost.Picks.Survey = 1
profiles[ana].Outpost.SurveyAt = 86400 * 20000 + math.floor(now) -- (no swings regained meanwhile)
advance(Rules.ClaimSeconds + 1)
local syncsBeforeBreak = synced[ana] or 0
local last = handlers.OutpostHit(ana, nextRock.Id)
check(last.Ok and last.PickBroke == "Survey Pick", "The pick didn't break at zero")
check((synced[ana] or 0) > syncsBeforeBreak, "A broken pick didn't sync the profile")
advance(1)
local broken = handlers.OutpostHit(ana, nextRock.Id)
check(not broken.Ok and broken.NoPick, "Mined with a broken pick")
-- Refills are Robux (StoreServer grants a receipt's swings through
-- addSwings): none for coins, and none take any.
check(handlers.OutpostBuyRefill == nil, "Refills are still sold for coins")
local coins = profiles[ana].Coins
local Refill, Mega = Rules.Refills.Refill, Rules.Refills.Mega
check(Server.addSwings(ana, Refill.Swings), "A refill's swings weren't added")
local bought = handlers.OutpostState(ana).State
check(
	bought.Active == "Survey" and bought.Picks.Survey == Refill.Swings and profiles[ana].Coins == coins,
	"A refill didn't put its swings in the pick (or took coins)"
)
-- Refills stack past the full charge (the extra goes first).
check(Server.addSwings(ana, Mega.Swings), "A second refill wasn't added")
check(handlers.OutpostState(ana).State.Picks.Survey == Refill.Swings + Mega.Swings, "Refills don't stack")
check(not Server.addSwings(ana, 0), "Added no swings")
-- Swing restores (Shared.SwingRestore: arena wins, dungeons, coupons) fill
-- toward the full charge, never past it; none while it's over full.
check(Server.restoreSwings(ana, 0.5) == 0, "A restore took a refilled pick")
profiles[ana].Outpost.Picks.Survey = 100
check(Server.restoreSwings(ana, 0.10) == 60, "10% isn't 60 swings")
check(handlers.OutpostState(ana).State.Picks.Survey == 160, "A restore didn't reach the pick")
profiles[ana].Outpost.Picks.Survey = Rules.Picks.Survey.Swings - 20
check(Server.restoreSwings(ana, 0.5) == 20, "A restore went past full")
check(Server.restoreSwings(ana, 0.25) == 0 and select(1, Server.charge(ana)) == Rules.Picks.Survey.Swings, "A full pick was restored")
check(Server.restoreSwings(ana, 0) == 0 and Server.restoreSwings({}, 0.5) == 0, "Nothing to restore, or no profile")
-- Time passes: the free pick regains its swings.
profiles[ana].Outpost.Picks.Survey = 0
profiles[ana].Outpost.SurveyAt -= Rules.FreeSwingSeconds * 5
check(handlers.OutpostState(ana).State.Picks.Survey == 5, "The free pick didn't regain swings over time")
profiles[ana].Outpost.SurveyAt -= Rules.FreeSwingSeconds * Rules.Picks.Survey.Swings
check(handlers.OutpostState(ana).State.Picks.Survey == Rules.Picks.Survey.Swings, "The free pick didn't refill")

-- A save from when picks were sold: their swings become extra swings
-- on the free pick, which is back in hand.
profiles[ben].Outpost = {
	Picks = { Survey = 10, Titan = 100, Plasma = 40 },
	Active = "Plasma",
	Rocks = 3,
	SurveyAt = 86400 * 20000 + math.floor(now),
}
local migrated = handlers.OutpostState(ben).State
check(
	migrated.Picks.Survey == 10 + 100 + 60 and migrated.Picks.Titan == nil and migrated.Picks.Plasma == nil,
	"An old save's picks didn't turn into swings"
)
check(migrated.Active == "Survey", "An old save kept a pick nobody sells in hand")

-- The secrets are retired: none hidden, none to find. The Motor Pool has
-- its mech bays.
check(#site.Secrets == 0, "A retired Easter egg was hidden again")
anaRoot.CFrame = R.CFrame.new(Rules.Location.Position)
local coinsBefore = profiles[ana].Coins
check(not handlers.OutpostSecret(ana, "Duck").Ok, "Found a retired secret")
check(not handlers.OutpostSecret(ana, "Nope").Ok, "Found a secret that doesn't exist")
check(profiles[ana].Coins == coinsBefore, "A retired secret paid out")
check(#site.Parking > 0, "The Motor Pool has no bays")
for _, bay in site.Parking do
	check(Rules.Machines[bay.Kind] ~= nil, "A bay for an unknown machine: " .. tostring(bay.Kind))
	check(bay.Kind == "Mole", "A bay without a Mole drill: " .. tostring(bay.Kind))
end

-- Only Ultra Rare and Legendary finds are called out to the server.
local lootCalls = 0
for _, call in announced do
	if string.find(call[2], "unearthed") then
		lootCalls += 1
	end
end
check(gemsAwarded > 0 and lootCalls == 0, "A Rare find was announced to the server")

-- Mining counts toward Tasks (and the onboarding funnel's first rock).
check(trained[ana] and (trained[ana].Mine or 0) > 0, "Popping rocks didn't count for Tasks")

-- Leaving.
check(handlers.OutpostLeave(ana).Ok and ana:GetAttribute("Outpost") == nil, "Couldn't leave")
check(
	ana.Character:FindFirstChild("OutpostPick") == nil and anaRoot:FindFirstChild("OutpostDuel") == nil,
	"Left with the mining kit on"
)

print(
	"PASS: "
		.. checks
		.. " Outpost checks (rock sizes, swings, claims, pops, loot, respawns, picks wearing out, Garrick's refills, old picks to swings, free pick charge, retired secrets, mech bays, enter/leave)"
)
