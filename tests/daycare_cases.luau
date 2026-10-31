-- lune run tests/daycare_cases.luau <repo>
-- The Kaiju Daycare (Shared.Daycare, Server.DaycareServer, Client.DaycarePen
-- and DaycareUI): STORE or TRAIN, the fee (pricy), training up to the cap,
-- the slots, boarding and collecting (out of the roster and back, trained,
-- at full health), and the pen showing everyone's in the server.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
-- (Lune has no Random: a small seeded one with the same methods)
local Random = {
	new = function(seed)
		local state = (seed or 1) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
env = setmetatable({
	Random = Random,
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	NumberRange = roblox.NumberRange,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
	bit32 = bit32,
	game = {
		GetService = function()
			return {
				Shared = names,
				FindFirstChild = function()
					return nil
				end,
			}
		end,
	},
	script = { Parent = names },
	require = shared,
}, { __index = _G })


local Daycare = shared("Daycare")
local Vector3 = roblox.Vector3
local Kaiju = shared("Kaiju")
local Kennel = shared("KaijuKennel")

-- The rules ------------------------------------------------------------------------------------------
local H = 3600
local function entry(mode, level, hours, at)
	return { Mode = mode, Hours = hours, At = at or 0, Record = { Level = level, Exp = 0 } }
end
-- STORE: by the hour, never past its cap; nothing trained.
local s1 = Daycare.result(entry("Store", 5), 10 * H)
check(s1.Fee == 10 * Daycare.Store.PerHour and s1.Level == 5 and s1.Done, "STORE: 10 hours isn't 10 hours' fee, or it trained")
check(Daycare.result(entry("Store", 5), 1000 * H).Fee == Daycare.Store.Max, "STORE's fee went past its cap")
check(Daycare.result(entry("Store", 5), 0).Fee == 0, "A fee for no time at all")
-- TRAIN: levels up, costs its rate an hour, done when its hours are up.
local t12 = Daycare.result(entry("Train", 5, 12), 12 * H)
check(t12.Level > 5 and t12.Done and t12.Left == 0, "12 hours of training: no levels, or not done")
check(t12.Fee == math.ceil(12 * Daycare.trainRate(5)), "12 hours of training isn't 12 hours at its rate: " .. t12.Fee)
local half = Daycare.result(entry("Train", 5, 12), 6 * H)
check(not half.Done and math.abs(half.Left - 6 * H) < 1 and half.Level <= t12.Level, "Half way: done already, or the time left is wrong")
-- About a level every 6-7 hours (Share 0.15 of a level an hour).
local day = Daycare.result(entry("Train", 10, 24), 24 * H)
check(day.Level == 13, "24 hours at level 10 isn't about 3 levels: " .. day.Level)
-- Kept after its training: the STORE rate on top.
local after = Daycare.result(entry("Train", 5, 4), 14 * H)
check(after.Fee == math.ceil(4 * Daycare.trainRate(5)) + 10 * Daycare.Store.PerHour and after.Done, "Kept after training isn't charged as STORE")
-- The cap: never trained past it, and the hours after it charged as kept.
local capped = Daycare.result(entry("Train", Daycare.Train.Cap - 1, 24), 24 * H)
check(capped.Level == Daycare.Train.Cap and capped.Done and capped.Trained < 24, "Trained past the cap, or kept training at it")
-- Pricy: a long stay is a real cost.
check(Daycare.quote(10, "Train", 12) >= 2000, "12 hours' training at level 10 is cheap: " .. Daycare.quote(10, "Train", 12))
check(Daycare.Store.PerHour * 24 >= 500, "A day's storage is cheap")

-- The pen: its kaiju stay inside its fence ---------------------------------------------------------
for i = 1, 6 do
	for t = 0, 120, 7.3 do
		local st = Kennel.state(100 + i, 6, 1e6 + t, Daycare.Pen)
		local d = (st.Position - Daycare.Pen.Middle) * Vector3.new(1, 0, 1)
		check(d.Magnitude <= Daycare.Pen.Fence - 1, "A Daycare kaiju walked through its fence")
		check(st.Position.Y == Daycare.Pen.Middle.Y, "A Daycare kaiju off its floor")
	end
end
check((Daycare.Pen.Middle - Kennel.Pen.Middle).Magnitude > Kennel.Pen.Fence + Daycare.Pen.Fence + 2, "The Daycare's pen overlaps the Kennel's")
-- (the Kennel's own pen unchanged)
local k = Kennel.state(1, 6, 12345)
check((k.Position - Kennel.Pen.Middle).Magnitude < Kennel.Pen.Fence, "The Kennel's pen moved")

-- The server: board, collect -----------------------------------------------------------------------------
local registered, coinsSpent = {}, {}
local profiles, synced = {}, 0
local clockNow = 1000000
local repl = roblox.Instance.new("Folder")
do
	local sharedFolder = roblox.Instance.new("Folder")
	sharedFolder.Name = "Shared"
	sharedFolder.Parent = repl
	for _, n in { "Daycare", "Kaiju", "Market" } do
		local m = roblox.Instance.new("Folder")
		m.Name = n
		m.Parent = sharedFolder
	end
end
local playersAdded = {}
local players = {}
local serverEnv = setmetatable({
	Instance = roblox.Instance,
	game = { GetService = function(_, name)
		if name == "Players" then
			return {
				GetPlayers = function() return players end,
				PlayerAdded = { Connect = function(_, fn) table.insert(playersAdded, fn) end },
				PlayerRemoving = { Connect = function() end },
			}
		elseif name == "ReplicatedStorage" then
			return repl
		end
		return {}
	end },
	script = { Parent = names },
	os = setmetatable({ time = function() return clockNow end }, { __index = os }),
	task = { spawn = function() end, wait = function() end },
	require = function(name)
		if typeof(name) == "Instance" then
			name = name.Name
		end
		if name == "PlayerData" then
			return {
				get = function(p) return profiles[p] end,
				sync = function() synced += 1 end,
				spendCoins = function(p, n, reason)
					local profile = profiles[p]
					if profile.Coins < n then return false end
					profile.Coins -= n
					table.insert(coinsSpent, { n, reason })
					return true
				end,
			}
		elseif name == "Shop" then
			return {
				register = function(n, fn) registered[n] = fn end,
				reply = function(ok, msg, extra) extra = extra or {}; extra.Ok, extra.Message = ok, msg; return extra end,
			}
		end
		return shared(name)
	end,
}, { __index = env })
-- (the pen's folder: Instance.new("Folder") parented to "ReplicatedStorage")
local Server = luau.load(fs.readFile(ROOT .. "/src/server/Systems/DaycareServer.luau"), { debugName = "DaycareServer", environment = serverEnv })()
Server.start()

local me = { UserId = 7, DisplayName = "Kristen", Parent = true, GetAttribute = function() return nil end }
players = { me }
local profile = { Coins = 50000 }
profiles[me] = profile
local roster = Kaiju.roster(profile)
local ids = {}
for i, species in { "Razorback", "Carapace", "Bulwark", "Scythe", "Razorback", "Carapace" } do
	local record = Kaiju.add(roster, species, { Id = "s" .. i, Tier = "Common", Element = "Fire", Cut = "Round" }, 6)
	ids[i] = record.Id
end
local outTeam = Kaiju.teamIds(roster)
local home = nil
for _, id in ids do
	if not table.find(outTeam, id) then
		home = home or id
	end
end
check(home ~= nil, "(test) no kaiju at home")
local state = registered.DaycareState(me)
check(state.Ok and state.Slots == Daycare.Slots and #state.Home > 0, "DaycareState: nothing at home to board")
for _, h in state.Home do
	check(not table.find(outTeam, h.Id), "The team that's out is offered for the Daycare")
end
-- Board: not the team out, a real mode, a real stay.
check(not registered.DaycareBoard(me, outTeam[1], "Store").Ok, "Boarded one out with you")
check(not registered.DaycareBoard(me, home, "Nap").Ok, "Boarded with no mode")
check(not registered.DaycareBoard(me, home, "Train", 7).Ok, "Trained for a stay that isn't offered")
local count = Kaiju.count(roster)
local boarded = registered.DaycareBoard(me, home, "Train", 12)
check(boarded.Ok and roster.List[home] == nil and Kaiju.count(roster) == count - 1, "Couldn't board one to train: " .. tostring(boarded.Message))
check(not registered.DaycareBoard(me, home, "Store").Ok, "Boarded the same one twice")
-- In the pen, for everyone here.
local penFolder = repl:FindFirstChild("DaycarePen")
check(penFolder and #penFolder:GetChildren() == 1, "It's not in the pen")
local shown = penFolder:GetChildren()[1]
check(shown:GetAttribute("Mode") == "Train" and shown:GetAttribute("Owner") == "Kristen" and shown:GetAttribute("Level") == 6, "Its plate in the pen is wrong")
-- The slots.
local others = {}
for _, id in ids do
	if roster.List[id] and not table.find(Kaiju.teamIds(roster), id) and Kaiju.supportId(roster) ~= id then
		table.insert(others, id)
	end
end
for i = 1, Daycare.Slots - 1 do
	check(registered.DaycareBoard(me, others[i], "Store").Ok, "Couldn't fill the Daycare's slots")
end
check(others[Daycare.Slots] == nil or not registered.DaycareBoard(me, others[Daycare.Slots], "Store").Ok, "Boarded past its slots")
-- Collect: not short of coins, trained, at full health, back in the roster.
clockNow += 12 * H
local key = nil
for k, e in profile.Daycare.Entries do
	if e.Mode == "Train" then key = k end
end
local owed = Daycare.result(profile.Daycare.Entries[key], clockNow).Fee
profile.Coins = owed - 1
check(not registered.DaycareCollect(me, key).Ok and profile.Daycare.Entries[key] ~= nil, "Collected without the coins")
profile.Coins = owed + 100
local before = Kaiju.count(roster)
local back = registered.DaycareCollect(me, key)
check(back.Ok and profile.Coins == 100 and coinsSpent[#coinsSpent][2] == "Daycare", "Collecting didn't charge its fee: " .. tostring(back.Message))
check(Kaiju.count(roster) == before + 1 and profile.Daycare.Entries[key] == nil, "It didn't come back to the roster")
local returned
for _, record in roster.List do
	if record.Soul and record.Soul.Id == "s" .. table.find(ids, home) then returned = record end
end
check(returned and returned.Level > 6 and returned.Health == nil, "It didn't come back trained and at full health")
check(not registered.DaycareCollect(me, key).Ok, "Collected the same one twice")
check(#penFolder:GetChildren() == Daycare.Slots - 1, "The pen still shows it")
-- Full roster: it waits.
local keep = Kaiju.MaxOwned
Kaiju.MaxOwned = Kaiju.count(roster)
local anyKey = next(profile.Daycare.Entries)
profile.Coins = 1e6
check(not registered.DaycareCollect(me, anyKey).Ok, "Collected into a full roster")
Kaiju.MaxOwned = keep

-- The window: a stay worked out ahead, the same as the server ----------------------------------------
local clientEnv = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	game = { GetService = function() return { Shared = names, Heartbeat = { Connect = function() end } } end },
	script = { Parent = { GemClient = {}, IronUi = { Colors = {}, new = function() end }, UiKit = {} } },
	require = function(m) if type(m) == "table" then return m end return shared(m) end,
}, { __index = env })
local UI = luau.load(fs.readFile(ROOT .. "/src/client/Modules/DaycareUI.luau"), { debugName = "DaycareUI", environment = clientEnv })()
local lvl, fee = UI.project(5, 12)
check(lvl == t12.Level and fee == t12.Fee, "The window's quote isn't what the server charges")
-- Wired in.
check(fs.readFile(ROOT .. "/src/server/Main.server.luau"):find("Systems.DaycareServer).start()", 1, true) ~= nil, "The server doesn't start the Daycare")
check(fs.readFile(ROOT .. "/src/client/Modules/KennelLife.luau"):find("DaycarePen.mount(frame)", 1, true) ~= nil, "The pen isn't built by the Kennel")
check(fs.readFile(ROOT .. "/src/client/CreatureAnimation.client.luau"):find('"KaijuDaycare"', 1, true) ~= nil, "The Daycare's kaiju don't move")
print(string.format("PASS: %d daycare checks (STORE and TRAIN, the fee, the cap, the pen, slots, boarding and collecting, the window's quote)", checks))
