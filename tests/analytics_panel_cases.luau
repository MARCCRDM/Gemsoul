-- lune run tests/analytics_panel_cases.luau <repo>
-- The Owners' ANALYTICS window's numbers: Shared.AnalyticsReport on a log it
-- knows the answers to (the same one tools/telemetry/test_report.py checks),
-- Server.Telemetry keeping everything since the server started, and
-- Server.AnalyticsPanel: owners only, THIS SERVER at once, TODAY and 7 DAYS
-- read from the saved log within the request budget, a finished hour's
-- logs read once.
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

local function loadShared(name, env)
	return luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env or setmetatable({}, { __index = _G }) })()
end
local Report = loadShared("AnalyticsReport")

-- 1. The report, on a log with known answers.
local DAY = 86400
local START = 1793491200 -- 2026-11-01 00:00 UTC
local rows = {}
local function add(server, ...)
	local row = { ... }
	row.server = server
	table.insert(rows, row)
end
for _, u in { 1, 2 } do
	add("aaaa", START + 60, u, "session_start", 0, "new", "US")
	add("aaaa", START + 660, u, "session_end", 600, 3, 100, 80)
	add("aaaa", START + 70, u, "onboarding", 1, "Joined")
end
add("aaaa", START + 80, 1, "onboarding", 2, "Style")
add("aaaa", START + 90, 1, "Purchase", 99, "Coins10k", "Robux")
add("aaaa", START + 95, 2, "Purchase", 1, "Old")
add("aaaa", START + 100, 1, "coins", 250, "Duel", "Gameplay")
add("aaaa", START + 101, 1, "coins", -50, "Store", "Shop")
add("aaaa", START + 102, 1, "IntroRound", 1, "Weapon", "Rare", "Won")
add("aaaa", START + 103, 2, "IntroRound", 1, "Weapon", "Lost", "Lost")
add("aaaa", START + 104, 1, "DuelFinished", 1, "Ranked", "Win", "1v1")
add("aaaa", START + 105, 2, "DuelFinished", 1, "Ranked", "Loss", "1v1")
add("aaaa", START + 300, 0, "server", 2, 700)
add("bbbb", START + 300, 0, "server", 3, 700)
add("aaaa", START + DAY + 60, 1, "session_start", 1, "returning", "US")
add("aaaa", START + 7 * DAY + 60, 2, "session_start", 7, "returning", "US")
add("aaaa", START + 110, 1, "store_funnel", 1, "R1 start · Sword", "IntroRounds")
add("aaaa", START + 111, 2, "store_funnel", 1, "R1 start · Sword", "IntroRounds")
add("aaaa", START + 112, 1, "store_funnel", 2, "R1 won · Sword", "IntroRounds")
add("aaaa", START + 113, 1, "store_funnel", 1, "Opened store", "Store")
local r = Report.build(rows)
check(r.Players == 2 and r.New == 2 and r.Returning == 0 and r.Sessions == 4, "Players and sessions")
check(r.AvgSession == 10 and r.MedianSession == 10, "Average session: " .. tostring(r.AvgSession))
check(r.Revenue == 99 and r.Purchases == 2 and r.Payers == 2, "Revenue: only Robux counts, every buyer's a payer")
check(r.PeakOnline == 5, "Peak online adds up the servers in one 5-minute bucket: " .. tostring(r.PeakOnline))
check(r.D1 and r.D1.Cohort == 2 and r.D1.Back == 1 and r.D1.Pct == 50, "Day-1 return")
check(#r.Funnel == 2 and r.Funnel[1].Users == 2 and r.Funnel[2].Users == 1 and r.Funnel[2].Drop == 50 and r.Funnel[2].Name == "Style", "The funnel")
check(#r.Rounds == 1 and r.Rounds[1].Won == 1 and r.Rounds[1].Lost == 1 and r.Rounds[1].Rare == 1 and r.Rounds[1].Slot == "Weapon", "Intro rounds")
check(r.Sources[1].Name == "Duel" and r.Sources[1].Value == 250 and r.Sinks[1].Name == "Store" and r.Sinks[1].Value == 50, "Coins in and out")
check(r.Products[1].Name == "Coins10k" and r.Products[1].Value == 99, "Robux by product")
check(r.Duels[1].Name == "Ranked" and r.Duels[1].Wins == 1 and r.Duels[1].Losses == 1, "Duels")
check(r.Countries[1].Name == "US" and r.Countries[1].Value == 2, "Countries count players, not sessions")
local intro = r.Funnels.IntroRounds
check(intro and #intro == 2 and intro[1].Users == 2 and intro[2].Users == 1 and intro[2].Drop == 50 and intro[2].Name == "R1 won · Sword", "The intro rounds' funnel")
check(r.Funnels.Store and r.Funnels.Store[1].Users == 1, "The Store's funnel")
local bands = {}
for _, band in r.Lengths do
	bands[band.Name] = band.Value
end
check(bands["10-20m"] == 2 and bands["under 2m"] == 0, "Session lengths")
-- Nothing yet: no errors, nothing made up.
local none = Report.build({})
check(none.Players == 0 and none.D1 == nil and none.AvgSession == nil and #none.Funnel == 0, "An empty log")
-- Today's newcomers can't have come back yet: no day-1 figure from one day.
local today = Report.build({ { START + 60, 1, "session_start", 0, "new", "US" } })
check(today.D1 == nil, "Day-1 return from a single day")

-- 2. Telemetry keeps everything since the server started (THIS SERVER).
local clock = START + 3600 * 5
local saved = {}
local tServices = {
	DataStoreService = { GetDataStore = function() return { SetAsync = function(_, key, value) saved[key] = value end } end },
	LocalizationService = {},
	Players = { GetPlayers = function() return {} end, PlayerRemoving = { Connect = function() end } },
	RunService = { IsStudio = function() return false end },
}
local T = luau.load(fs.readFile(ROOT .. "/src/server/Systems/Telemetry.luau"), {
	environment = setmetatable({
		game = { GetService = function(_, n) return tServices[n] end, JobId = "abcd1234-ffff", PlaceVersion = 700, BindToClose = function() end },
		script = { Parent = {} },
		os = setmetatable({ time = function() return clock end }, { __index = os }),
		task = { spawn = function() end, wait = task.wait },
		warn = function() end,
	}, { __index = _G }),
})()
T.KeepHere = 10
for i = 1, 5 do
	T.record(i, "session_start", 0, "new")
end
clock += 3600 -- (a new hour: the hour's rows start again, the server's don't)
T.record(6, "session_start", 0, "new")
check(#T.here() == 6, "THIS SERVER lost rows at the hour: " .. #T.here())
for i = 1, 2000 do
	T.record(i, "coins", 1, "Duel")
end
check(#T.here() <= T.KeepHere + 2000 and T.here()[#T.here()][3] == "coins", "THIS SERVER's rows aren't trimmed to KeepHere")
check(T.Server == "abcd1234" and T.store() ~= nil, "Telemetry's server id and store")

-- 3. The panel.
local now = START + 2 * DAY + 3600 * 10 + 30 * 60 -- day 3, 10:30 UTC
local owners = { [11] = true }
local function player(id, name)
	local attrs = {}
	return {
		UserId = id, Name = name, DisplayName = name,
		GetAttribute = function(_, k) return attrs[k] end,
		SetAttribute = function(_, k, v) attrs[k] = v end,
	}
end
local owner, stranger = player(11, "Devvolver"), player(22, "Someone")
local logs = {} -- key -> value
local function log(day, hour, server, rowList)
	logs[string.format("ev/%s/%02d/%s", os.date("!%Y-%m-%d", START + day * DAY), hour, server)] = { V = 1, Server = server, Rows = rowList }
end
log(0, 9, "aaaa", { { START + 9 * 3600, 5, "session_start", 0, "new", "US" } })
log(2, 8, "aaaa", { { START + 2 * DAY + 8 * 3600, 6, "session_start", 0, "new", "BR" } })
log(2, 10, "bbbb", { { START + 2 * DAY + 10 * 3600 + 60, 7, "session_start", 0, "returning", "US" } })
local reads, lists, budget = {}, 0, 100
local store = {
	ListKeysAsync = function(_, prefix)
		lists += 1
		local found = {}
		for key in logs do
			if string.sub(key, 1, #prefix) == prefix then
				table.insert(found, { KeyName = key })
			end
		end
		table.sort(found, function(a, b) return a.KeyName < b.KeyName end)
		return { IsFinished = true, GetCurrentPage = function() return found end, AdvanceToNextPageAsync = function() end }
	end,
	GetAsync = function(_, key)
		reads[key] = (reads[key] or 0) + 1
		return logs[key]
	end,
}
local registered = {}
local marked = {} -- (DevAccounts.set: who was marked NOT COUNTED)
local Telemetry = { here = function() return { { now - 120, 11, "session_start", 0, "returning", "US" } } end, store = function() return store end, Since = now - 3600, Server = "cccc" }
local stubs = {
	DevAlerts = { owner = function(id) return owners[id] == true end },
	DevAccounts = {
		listed = function() return { [11] = true } end,
		excluded = function(p) return p.UserId == 11 end,
		set = function(p, on) marked[p.UserId] = on; return true end,
	},
	PlayerData = { get = function() return { Funnel = { Joined = true, Element = true }, IntroRounds = { Won = 2, Losses = 0, Pieces = {} } } end },
	Funnel = { Steps = { "Joined", "Style", "Element", "Kit" } },
	Shop = {
		reply = function(ok, message, extra)
			local out = extra or {}
			out.Ok, out.Message = ok, message
			return out
		end,
		register = function(name, fn) registered[name] = fn end,
	},
	Telemetry = Telemetry,
}
local sharedRef = setmetatable({}, { __index = function(_, k) return { Shared = k } end })
local panelServices = {
	DataStoreService = { GetRequestBudgetForRequestType = function() return budget end },
	Players = {
		GetPlayers = function() return { owner } end,
		GetPlayerByUserId = function(_, id) return if id == 11 then owner else nil end,
		PlayerAdded = { Connect = function() end },
	},
	ReplicatedStorage = { Shared = sharedRef },
}
local sharedEnv = setmetatable({}, { __index = _G })
local Panel = luau.load(fs.readFile(ROOT .. "/src/server/Systems/AnalyticsPanel.luau"), {
	environment = setmetatable({
		game = { GetService = function(_, n) return panelServices[n] end },
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function(ref)
			if type(ref) == "table" and ref.Shared then
				return loadShared(ref.Shared, sharedEnv)
			end
			return stubs[ref]
		end,
		os = setmetatable({ time = function() return now end }, { __index = os }),
		task = task,
		warn = function() end,
		Enum = { DataStoreRequestType = { GetAsync = "GetAsync", ListAsync = "ListAsync" } },
	}, { __index = _G }),
})()
-- Pure.
check(Panel.settled("ev/2026-11-03/08/aaaa", now) and not Panel.settled("ev/2026-11-03/10/aaaa", now), "A finished hour's log is settled, this hour's isn't")
check(Panel.settled("ev/2026-11-03/09/aaaa", now) and not Panel.settled("ev/2026-11-03/09/aaaa", now - 20 * 60), "Last hour's log isn't settled till its servers' last saves are in")
local week = Panel.days("Week", now)
check(#week == 7 and week[7] == "2026-11-03" and week[1] == "2026-10-28", "7 DAYS: " .. table.concat(week, ","))
check(#Panel.days("Today", now) == 1, "TODAY is one day")
Panel.start()
check(registered.AnalyticsReport ~= nil, "No AnalyticsReport request")
check(owner:GetAttribute("AnalyticsOwner") == true and stranger:GetAttribute("AnalyticsOwner") == nil, "Only the owner gets the button")
-- Owners only.
check(registered.AnalyticsReport(stranger, "Server").Ok == false, "A stranger got the numbers")
check(registered.AnalyticsReport(owner, "Nonsense").Ok == false, "An unknown range answered")
-- THIS SERVER: at once, with who's here.
local here = registered.AnalyticsReport(owner, "Server")
check(here.Ok and here.Report.Players == 0 and #here.Here == 1, "THIS SERVER counted the owner")
check(here.Here[1].Excluded == true and here.Here[1].Listed == true and here.Here[1].UserId == 11, "The owner isn't shown as a dev account")
-- An owner marks someone here NOT COUNTED; nobody else can.
check(registered.AnalyticsExclude(stranger, 11, true).Ok == false, "A stranger marked an account")
check(registered.AnalyticsExclude(owner, 999, true).Ok == false, "Marked someone who isn't here")
check(registered.AnalyticsExclude(owner, 11, true).Ok and marked[11] == true, "The owner couldn't mark an account")
check(here.Here[1].Step == 3 and here.Here[1].StepName == "Element" and here.Here[1].Rounds == 2 and here.Here[1].Minutes == 2, "Who's here: step, rounds, minutes")
-- TODAY: read in the background; asking again gets what's in.
local first = registered.AnalyticsReport(owner, "Today")
check(first.Ok and first.Loading ~= nil, "TODAY has no loading progress")
task.wait(0.3)
local second = registered.AnalyticsReport(owner, "Today")
task.wait(Panel.Rebuild + 0.1)
second = registered.AnalyticsReport(owner, "Today")
check(second.Loading.Done == 2 and second.Loading.Total == 2, string.format("TODAY read %d of %d", second.Loading.Done, second.Loading.Total))
check(second.Report.Players == 2 and second.Report.New == 1, "TODAY's report: " .. tostring(second.Report.Players))
-- 7 DAYS: every day's logs, the older day's too.
registered.AnalyticsReport(owner, "Week")
task.wait(0.3)
task.wait(Panel.Rebuild + 0.1)
local weekly = registered.AnalyticsReport(owner, "Week")
check(weekly.Loading.Total == 3 and weekly.Report.Players == 3, "7 DAYS' report: " .. tostring(weekly.Report.Players))
-- A finished hour's log is read once; this hour's again when asked a minute on.
local settledKey = string.format("ev/%s/08/aaaa", os.date("!%Y-%m-%d", START + 2 * DAY))
local liveKey = string.format("ev/%s/10/bbbb", os.date("!%Y-%m-%d", START + 2 * DAY))
check(reads[settledKey] == 1, "A finished hour's log was read again: " .. tostring(reads[settledKey]))
now += 61 + Panel.ListAgain
registered.AnalyticsReport(owner, "Today")
task.wait(0.3)
check(reads[settledKey] == 1 and reads[liveKey] >= 2, "This hour's log isn't read afresh")
-- The budget: it waits rather than spend what the game needs.
Panel.BudgetWait = 1
budget = 0
local before = reads[liveKey]
now += 61 + Panel.ListAgain
registered.AnalyticsReport(owner, "Today")
task.wait(0.3)
check(reads[liveKey] == before, "Read with no request budget left")
task.wait(1.5)
check(reads[liveKey] == before, "Read with no request budget left, after waiting")
budget = 100
-- No store (Studio without API access): it says so.
Telemetry.store = function() return nil end
registered.AnalyticsReport(owner, "Week")
task.wait(1.5)
now += 61 + Panel.ListAgain
local problem = registered.AnalyticsReport(owner, "Week")
task.wait(0.3)
problem = registered.AnalyticsReport(owner, "Week")
check(type(problem.Problem) == "string", "No word when the log can't be reached")

print(string.format("PASS: %d analytics panel checks (the report's numbers, THIS SERVER's rows, owners only, TODAY and 7 DAYS read in the background within budget, finished hours read once)", checks))
process.exit(0)
