-- lune run tests/telemetry_cases.luau <repo>
-- The game's own event log (Server.Telemetry): its keys, the device report,
-- rows saved under this server's key for the hour, a new key each hour and
-- past MaxRows, Studio's own store, and the game's Analytics passing through
-- to it as well as to Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")
local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local saved, storeName = {}, nil
local studio = false
local clock = 1793500000
local loadedHook, removingHooks = nil, {}
local sent = { custom = {}, economy = {}, funnel = {} }
local Analytics = {
	send = {
		economy = function(...) table.insert(sent.economy, { ... }) end,
		custom = function(...) table.insert(sent.custom, { ... }) end,
		funnel = function(...) table.insert(sent.funnel, { ... }) end,
	},
}
local Funnel = { log = function() end }
local PlayerData = { Loaded = { Connect = function(_, fn) loadedHook = fn end }, get = function(p) return p.Profile end }
local services = {
	DataStoreService = { GetDataStore = function(_, name)
		storeName = name
		return { SetAsync = function(_, key, value) saved[key] = value end }
	end },
	LocalizationService = { GetCountryRegionForPlayerAsync = function() return "US" end },
	Players = {
		GetPlayers = function() return {} end,
		PlayerRemoving = { Connect = function(_, fn) table.insert(removingHooks, fn) end },
	},
	RunService = { IsStudio = function() return studio end },
}
local env = setmetatable({
	game = { GetService = function(_, n) return services[n] end, JobId = "abcd1234-ffff", PlaceVersion = 700, BindToClose = function() end },
	script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
	require = function(name)
		return ({ Analytics = Analytics, Funnel = Funnel, PlayerData = PlayerData })[name]
	end,
	os = setmetatable({ time = function() return clock end }, { __index = os }),
	task = { spawn = function() end, wait = task.wait },
	warn = function() end,
}, { __index = _G })
local T = luau.load(fs.readFile(ROOT .. "/src/server/Systems/Telemetry.luau"), { environment = env })()

-- Keys: by the UTC hour, this server's own.
check(T.key(0, "abcd1234") == "ev/1970-01-01/00/abcd1234", "Key: " .. T.key(0, "abcd1234"))
check(T.key(3600 * 25, "s", 2) == "ev/1970-01-02/01/s-2", "Second part's key")
-- The device.
check(T.platform({ Touch = true, Keyboard = false, X = 844, Y = 390 }) == "phone", "A phone isn't a phone")
check(T.platform({ Touch = true, Keyboard = false, X = 1180, Y = 820 }) == "tablet", "A tablet isn't a tablet")
check(T.platform({ Touch = false, Keyboard = true, X = 1920, Y = 1080 }) == "desktop", "A computer isn't desktop")
check(T.platform({ Console = true }) == "console" and T.platform(nil) == "unknown", "Console / nothing")

-- Recording and saving.
local player = { UserId = 42, AccountAge = 3, Name = "p", Profile = { FirstJoin = clock - 30, Coins = 900 },
	GetAttribute = function(_, k) return if k == "MinerLevel" then 4 else nil end,
	GetNetworkPing = function() return 0.08 end }
T.start(nil)
check(loadedHook ~= nil, "Sessions aren't watched")
loadedHook(player)
T.record(player, "Purchase", 99, "Coins10k", "Robux")
T.flush()
local key = T.key(clock, "abcd1234")
check(storeName == T.Name, "Wrote to " .. tostring(storeName))
local value = saved[key]
check(value and value.V == 1 and #value.Rows == 2, "This hour's rows weren't saved under the server's key")
local start = value.Rows[1]
check(start[2] == 42 and start[3] == "session_start" and start[4] == 3 and start[5] == "new" and start[6] == "US", "session_start row wrong")
check(value.Rows[2][3] == "Purchase" and value.Rows[2][4] == 99, "Purchase row wrong")
-- The session's end, with its length.
clock += 125
for _, fn in removingHooks do fn(player) end
T.flush()
local rows = saved[key].Rows
local ending = rows[#rows]
check(ending[3] == "session_end" and ending[4] == 125 and ending[5] == 4 and ending[6] == 900 and ending[7] == 80, "session_end row wrong")
-- A new hour: a new key; the old one keeps its rows.
clock += 3600
T.record(player, "x")
T.flush()
check(saved[T.key(clock, "abcd1234")] and #saved[T.key(clock, "abcd1234")].Rows == 1 and #saved[key].Rows == #rows, "The hour didn't roll over")
-- Past MaxRows: the next part.
T.MaxRows = 3
T.record(player, "a"); T.record(player, "b"); T.record(player, "c")
T.flush()
check(saved[T.key(clock, "abcd1234", 2)] ~= nil and #saved[T.key(clock, "abcd1234", 2)].Rows == 1, "No second part past MaxRows")
T.MaxRows = 20000

-- The game's Analytics: recorded here too, and still sent to Roblox.
Analytics.send.custom(player, "DuelFinished", 1, { CustomField01 = "Ranked", CustomField02 = "Win" })
Analytics.send.economy(player, false, 50, 850, "Shop", "Store")
Funnel.log(player, 9, "Socketed")
check(#sent.custom == 1 and #sent.economy == 1, "Roblox's sends stopped")
local last = {}
for _, row in (function() T.flush(); local k = T.key(clock, "abcd1234", 2); return saved[k].Rows end)() do
	last[row[3]] = row
end
check(last.DuelFinished and last.DuelFinished[5] == "Ranked" and last.DuelFinished[6] == "Win", "A custom event wasn't recorded")
check(last.coins and last.coins[4] == -50 and last.coins[5] == "Store", "A coin sink wasn't recorded")
check(last.onboarding and last.onboarding[4] == 9 and last.onboarding[5] == "Socketed", "An onboarding step wasn't recorded")
print(string.format("PASS: %d telemetry checks", checks))
