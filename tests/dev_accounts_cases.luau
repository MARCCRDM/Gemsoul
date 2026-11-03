-- lune run tests/dev_accounts_cases.luau <repo>
-- Dev and test accounts left out of every number (Server.DevAccounts): who's
-- left out, and that nothing of theirs reaches Roblox's Analytics (events,
-- funnels: Server.Analytics, Server.Funnel) or the game's own log
-- (Server.Telemetry), while everyone else's still does; the reports drop
-- them, their rows from before they were marked too (Shared.AnalyticsReport).
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

local function fakePlayer(id)
	local p = { UserId = id, Name = "p" .. id, DisplayName = "P" .. id, attrs = {} }
	function p.IsA(_, class) return class == "Player" end
	function p.GetAttribute(self, k) return self.attrs[k] end
	function p.SetAttribute(self, k, v) self.attrs[k] = v end
	function p.GetAttributeChangedSignal() return { Connect = function() end } end
	return p
end
local OWNER, TESTER, LISTED, TEST, REAL, RESET = 11, 22, 33, 44, 55, 66
local players = {}
for _, id in { OWNER, TESTER, LISTED, TEST, REAL, RESET } do
	players[id] = fakePlayer(id)
end
local profiles = {
	[TEST] = { Funnel = {} },
	[REAL] = { Funnel = {} },
	[RESET] = { Funnel = {}, DevBackup = { Coins = 9 } },
	[OWNER] = { Funnel = {} },
}
local studio = false
local Config = { Playtest = { Owners = { OWNER }, Testers = { TESTER }, NoAnalytics = { LISTED } } }
local PlayerData = { get = function(p) return profiles[p.UserId] end }
local sent = {} -- what reached Roblox: { kind, userId, ... }
local logged = {} -- the game's own log's rows
local Players = {
	GetPlayerByUserId = function(_, id) return players[id] end,
	GetPlayers = function() return {} end,
	PlayerRemoving = { Connect = function() end },
	PlayerAdded = { Connect = function() end },
}
local AnalyticsService = {
	LogCustomEvent = function(_, p, name) table.insert(sent, { "custom", p.UserId, name }) end,
	LogEconomyEvent = function(_, p) table.insert(sent, { "economy", p.UserId }) end,
	LogFunnelStepEvent = function(_, p, funnel, _, step) table.insert(sent, { "funnel", p.UserId, funnel, step }) end,
	LogOnboardingFunnelStepEvent = function(_, p, step, name) table.insert(sent, { "onboarding", p.UserId, step, name }) end,
}
local services = {
	Players = Players,
	RunService = { IsStudio = function() return studio end },
	AnalyticsService = AnalyticsService,
	HttpService = { GenerateGUID = function() return "guid" end },
	DataStoreService = { GetDataStore = function() return { SetAsync = function() end } end },
	LocalizationService = {},
	ReplicatedStorage = { Shared = { Config = "Config" } },
}
local modules = {}
local function env(extra)
	return setmetatable(extra or {}, { __index = _G })
end
local function load(path, name, requires)
	local fn = luau.load(fs.readFile(ROOT .. path), {
		debugName = name,
		environment = env({
			game = { GetService = function(_, n) return services[n] end, JobId = "abcd1234", PlaceVersion = 1, BindToClose = function() end },
			script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
			require = function(ref)
				if ref == "Config" then return Config end
				return requires[ref] or modules[ref] or error("no module " .. tostring(ref))
			end,
			task = { spawn = function() end, wait = task.wait, delay = function() end },
			warn = function() end,
			typeof = function(v) if type(v) == "table" and v.IsA then return "Instance" end return typeof(v) end,
		}),
	})
	modules[name] = fn()
	return modules[name]
end
local Telemetry = load("/src/server/Systems/Telemetry.luau", "Telemetry", { PlayerData = PlayerData })
-- (what the log keeps: Telemetry.here)
local Analytics = load("/src/server/Systems/Analytics.luau", "Analytics", {})
local Funnel = load("/src/server/Systems/Funnel.luau", "Funnel", { PlayerData = PlayerData, Remotes = {} })
local Journey = load("/src/server/Systems/Journey.luau", "Journey", {})
local DevAccounts = load("/src/server/Systems/DevAccounts.luau", "DevAccounts", { PlayerData = PlayerData })
DevAccounts.start()
-- (the first session's journey leaves them out too: Server.Journey)
check(Journey.excluded == DevAccounts.excluded, "Dev accounts aren't left out of the journey")

-- Who's left out.
check(DevAccounts.excluded(players[OWNER]) and DevAccounts.excluded(OWNER), "An Owner counts")
check(DevAccounts.excluded(players[TESTER]), "A Tester counts")
check(DevAccounts.excluded(players[LISTED]), "A NoAnalytics account counts")
check(DevAccounts.excluded(players[RESET]), "An account that's used DEV > NEW PLAYER counts")
check(not DevAccounts.excluded(players[REAL]) and not DevAccounts.excluded(players[TEST]), "A real player's left out")
check(not DevAccounts.excluded("nonsense"), "Nonsense is left out")
check(DevAccounts.listed()[OWNER] and DevAccounts.listed()[TESTER] and DevAccounts.listed()[LISTED], "listed() misses one")
studio = true
check(DevAccounts.excluded(players[REAL]), "Studio play counts")
studio = false

-- Marked NOT COUNTED (the ANALYTICS window): kept on the account, and a
-- log row the reports go by.
check(DevAccounts.set(players[TEST], true) and profiles[TEST].NoAnalytics == true, "Couldn't mark a test account")
check(DevAccounts.excluded(players[TEST]), "A marked account still counts")
local marks = {}
for _, row in Telemetry.here() do
	if row[3] == "analytics_excluded" then
		table.insert(marks, row)
	end
end
check(#marks == 1 and marks[1][2] == TEST and marks[1][4] == 1, "No log row for the mark")

-- Nothing of theirs goes out; a real player's does.
for _, id in { OWNER, TEST, RESET, REAL } do
	local p = players[id]
	Analytics.event(p, "DuelFinished", 1, "Ranked", "Win")
	Analytics.introStep(p, 1)
	Funnel.reach(p, "Joined")
	Telemetry.record(p, "session_start", 0, "new", "US")
	Telemetry.record(id, "device", 1, "phone")
end
local fromReal, fromDev = 0, 0
for _, s in sent do
	if s[2] == REAL then
		fromReal += 1
	else
		fromDev += 1
	end
end
check(fromDev == 0, fromDev .. " sends to Roblox from dev accounts")
check(fromReal == 3, "A real player's sends didn't all go: " .. fromReal)
local rowsBy = {}
for _, row in Telemetry.here() do
	if row[3] ~= "analytics_excluded" then
		rowsBy[row[2]] = (rowsBy[row[2]] or 0) + 1
	end
end
check(rowsBy[REAL] == 2 and rowsBy[OWNER] == nil and rowsBy[TEST] == nil and rowsBy[RESET] == nil, "The log kept dev accounts' rows")
-- (the funnel step's still reached for them: no asking again)
check(profiles[TEST].Funnel.Joined == true, "A dev account's funnel step wasn't marked reached")
-- Counted again.
DevAccounts.set(players[TEST], false)
check(profiles[TEST].NoAnalytics == nil and not DevAccounts.excluded(players[TEST]), "Couldn't count an account again")

-- The reports: listed accounts and the marked ones are dropped, the marked
-- ones' rows from before the mark too; the latest mark wins.
local Report = luau.load(fs.readFile(ROOT .. "/src/shared/AnalyticsReport.luau"), { environment = env() })()
local rows = {
	{ 100, REAL, "session_start", 0, "new", "US" },
	{ 100, OWNER, "session_start", 0, "new", "US" },
	{ 100, TEST, "session_start", 0, "new", "US" }, -- before it was marked
	{ 200, TEST, "analytics_excluded", 1 },
	{ 100, 77, "session_start", 0, "new", "US" },
	{ 200, 77, "analytics_excluded", 1 },
	{ 300, 77, "analytics_excluded", 0 }, -- counted again
}
local r = Report.build(rows, { Exclude = { [OWNER] = true } })
check(r.Players == 2 and r.New == 2, "The report kept dev accounts: " .. r.Players .. " players")
local skip = Report.excludedIn(rows, { [OWNER] = true })
check(skip[OWNER] and skip[TEST] and not skip[77] and not skip[REAL], "Who the report leaves out")
check(r.Events[1] == nil or r.Events[1].Name ~= "analytics_excluded", "The marks show as events")

-- Micro-interactions (Server.UiTrack): a real player's taps and windows
-- reach the log and the report; a dev account's don't; junk is dropped.
do
	local handler
	local UiTrack = load("/src/server/Systems/UiTrack.luau", "UiTrack", {
		Remotes = { UiTrack = { OnServerEvent = { Connect = function(_, fn) handler = fn end } } },
	})
	UiTrack.start()
	local function rowsOf(name)
		local out = {}
		for _, row in Telemetry.here() do
			if row[3] == name then
				table.insert(out, row)
			end
		end
		return out
	end
	handler(players[REAL], {
		Taps = { ["IntroRounds/Next"] = 3, ["Inventory/EQUIP"] = 1, ["bad"] = 5, ["X/Y"] = "lots" },
		Windows = { { Name = "Inventory", Seconds = 12.34, FirstTap = 4.2 }, { Name = "Shop", Seconds = 3 }, { Name = 5, Seconds = 1 } },
	})
	handler(players[OWNER], { Taps = { ["IntroRounds/Next"] = 9 }, Windows = { { Name = "Inventory", Seconds = 2 } } })
	handler(players[REAL], "junk")
	local tapRows, windowRows = rowsOf("ui_tap"), rowsOf("ui_window")
	check(#tapRows == 2 and #windowRows == 2, string.format("UiTrack rows: %d taps, %d windows", #tapRows, #windowRows))
	for _, row in tapRows do
		check(row[2] == REAL, "A dev account's taps were logged")
	end
	local report = Report.build(Telemetry.here())
	check(report.Taps[1] and report.Taps[1].Name == "IntroRounds/Next" and report.Taps[1].Value == 3 and report.Taps[1].Players == 1, "The report's TAPS")
	local inv
	for _, w in report.Windows do
		if w.Name == "Inventory" then
			inv = w
		end
	end
	check(inv and inv.Value == 1 and inv.AvgSeconds == 12.3 and inv.AvgFirstTap == 4.2 and inv.NoTap == 0, "The report's WINDOWS")
	local flood = { Taps = {} }
	for i = 1, 200 do
		flood.Taps["W/B" .. i] = 1
	end
	handler(players[REAL], flood)
	check(#rowsOf("ui_tap") <= 2 + UiTrack.MaxRows, "A flood got past the per-minute cap")
end

print(string.format("PASS: %d dev account checks (Owners, Testers, NoAnalytics, DEV resets, Studio and marked accounts left out of Roblox's Analytics, the funnels and the log; reports drop them, their earlier rows too; micro-interactions logged for real players only, capped)", checks))
process.exit(0)
