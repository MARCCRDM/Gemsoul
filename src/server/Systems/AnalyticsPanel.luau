--[[
	The ANALYTICS window's numbers (Client AnalyticsUI), for the game's
	Owners only (Config.Playtest.Owners; the player attribute AnalyticsOwner
	shows them the button, and every request is checked here again).

	  "AnalyticsReport", range    range: "Server" | "Today" | "Week"
	  "AnalyticsExclude", userId, excluded   a player here: left out of the
	                              numbers or counted again (Server.DevAccounts)

	Dev and test accounts are left out of every report (DevAccounts.listed,
	and anyone marked NOT COUNTED: their rows from before too).

	  Server   this server since it started (Telemetry.here): instant, and
	           who's here now: name, minutes in, onboarding step, intro
	           rounds won
	  Today    every server today (UTC), from the event log in the
	  Week     DataStore (Telemetry.store), the last 7 UTC days. The log's
	           keys are read a few at a time, within the DataStore's
	           request budget, in the background: each reply has what's in
	           so far and how far it's got (Loading = { Done, Total }); the
	           window asks again till it's all in. A key whose hour is over
	           is kept (it won't change again); this hour's are read afresh.
	           Up to FlushEvery (5 minutes) behind, as each server saves.

	Every report is Shared.AnalyticsReport's.

	  AnalyticsPanel.start()
	  AnalyticsPanel.settled(key, now) -> bool     (pure: its hour is over)
	  AnalyticsPanel.days(range, now) -> { "YYYY-MM-DD" }   (pure)
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsReport = require(ReplicatedStorage.Shared.AnalyticsReport)
local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
local DevAccounts = require(script.Parent.DevAccounts)
local DevAlerts = require(script.Parent.DevAlerts)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local Telemetry = require(script.Parent.Telemetry)

local AnalyticsPanel = {}

AnalyticsPanel.Days = { Today = 1, Week = 7 }
AnalyticsPanel.ListAgain = 120 -- seconds before a range's keys are listed again
AnalyticsPanel.Settle = 15 * 60 -- an hour's keys are final this long after it ends
AnalyticsPanel.Spare = 10 -- GetAsync budget left for the game itself
AnalyticsPanel.BudgetWait = 20 -- seconds to wait for it before giving up a pass
AnalyticsPanel.Rebuild = 2 -- seconds between rebuilding a range's report as it loads
AnalyticsPanel.MaxRows = 400000

local reply = Shop.reply

-- The UTC days a range covers, today last.
function AnalyticsPanel.days(range: string, now: number): { string }
	local n = AnalyticsPanel.Days[range] or 1
	local out = {}
	for i = n - 1, 0, -1 do
		table.insert(out, os.date("!%Y-%m-%d", now - i * 86400) :: string)
	end
	return out
end

-- Whether a log key's hour is over (and the servers' last saves of it are in).
function AnalyticsPanel.settled(key: string, now: number): boolean
	local hour = string.match(key, "^ev/(%d+%-%d+%-%d+/%d+)/")
	if not hour then
		return true
	end
	-- ("YYYY-MM-DD/HH" sorts as time does)
	return hour <= os.date("!%Y-%m-%d/%H", now - 3600 - AnalyticsPanel.Settle) :: string
end

local cache: { [string]: { any } } = {} -- a key's rows
local readAt: { [string]: number } = {}
local loaders = {}

-- Waits (up to BudgetWait seconds) till the game can spare a request of
-- this kind; false if it can't: that pass stops, the next ask tries again.
local function waitBudget(kind: Enum.DataStoreRequestType): boolean
	for _ = 1, AnalyticsPanel.BudgetWait do
		local ok, left = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, kind)
		if not ok or left > AnalyticsPanel.Spare then
			return true
		end
		task.wait(1)
	end
	return false
end

local function listKeys(ds, prefix: string): { string }?
	local keys = {}
	if not waitBudget(Enum.DataStoreRequestType.ListAsync) then
		return nil
	end
	local ok, pages = pcall(ds.ListKeysAsync, ds, prefix, 100)
	if not ok then
		warn("[Analytics] couldn't list " .. prefix .. ": " .. tostring(pages))
		return nil
	end
	while true do
		for _, entry in pages:GetCurrentPage() do
			table.insert(keys, entry.KeyName)
		end
		if pages.IsFinished then
			break
		end
		if not waitBudget(Enum.DataStoreRequestType.ListAsync) or not pcall(pages.AdvanceToNextPageAsync, pages) then
			break
		end
	end
	return keys
end

local function readKey(ds, key: string): boolean
	if not waitBudget(Enum.DataStoreRequestType.GetAsync) then
		return false
	end
	local ok, value = pcall(ds.GetAsync, ds, key)
	if not ok then
		warn("[Analytics] couldn't read " .. key .. ": " .. tostring(value))
		return false
	end
	local rows = {}
	if type(value) == "table" and type(value.Rows) == "table" then
		local server = value.Server
		for _, row in value.Rows do
			if type(row) == "table" then
				row.server = server
				table.insert(rows, row)
			end
		end
	end
	cache[key] = rows
	readAt[key] = os.time()
	return true
end

local function loaderOf(range: string)
	local loader = loaders[range]
	if not loader then
		loader = { Keys = {}, ListedAt = 0, Busy = false, Report = nil, BuiltAt = 0, Dirty = true, Problem = nil }
		loaders[range] = loader
	end
	return loader
end

-- Lists the range's keys (again, after ListAgain) and reads what isn't in.
local function load(range: string)
	local loader = loaderOf(range)
	if loader.Busy then
		return
	end
	loader.Busy = true
	task.spawn(function()
		local ok, problem = pcall(function()
			local ds = Telemetry.store()
			if not ds then
				loader.Problem = "The event log can't be reached here (in Studio: turn on Studio access to API services)."
				return
			end
			local now = os.time()
			if now - loader.ListedAt >= AnalyticsPanel.ListAgain or #loader.Keys == 0 then
				local keys, whole = {}, true
				for _, day in AnalyticsPanel.days(range, now) do
					local found = listKeys(ds, "ev/" .. day .. "/")
					if found then
						table.move(found, 1, #found, #keys + 1, keys)
					else
						whole = false
					end
				end
				if whole or #loader.Keys == 0 then
					loader.Keys, loader.ListedAt = keys, if whole then now else loader.ListedAt
					loader.Dirty = true
				end
			end
			for _, key in loader.Keys do
				local fresh = cache[key] ~= nil and (AnalyticsPanel.settled(key, os.time()) or os.time() - (readAt[key] or 0) < 60)
				if not fresh then
					if readKey(ds, key) then
						loader.Dirty = true
					elseif not cache[key] then
						break -- (no budget, or the store's refusing: next ask)
					end
				end
			end
			loader.Problem = nil
		end)
		if not ok then
			loader.Problem = tostring(problem)
			warn("[Analytics] " .. tostring(problem))
		end
		loader.Busy = false
	end)
end

local function progress(loader)
	local done = 0
	for _, key in loader.Keys do
		if cache[key] then
			done += 1
		end
	end
	return done, #loader.Keys
end

local function rangeReport(range: string)
	local loader = loaderOf(range)
	if loader.Dirty and os.clock() - loader.BuiltAt >= AnalyticsPanel.Rebuild then
		local rows = {}
		local from = os.time() - os.time() % 86400 - ((AnalyticsPanel.Days[range] or 1) - 1) * 86400
		for _, key in loader.Keys do
			for _, row in cache[key] or {} do
				if (tonumber(row[1]) or 0) >= from and #rows < AnalyticsPanel.MaxRows then
					table.insert(rows, row)
				end
			end
		end
		loader.Report = AnalyticsReport.build(rows, { Exclude = DevAccounts.listed() })
		loader.BuiltAt = os.clock()
		loader.Dirty = false
	end
	return loader.Report
end

-- Who's in this server now: name, minutes in, onboarding step, rounds won.
local function here(): { any }
	local joined: { [number]: number } = {}
	for _, row in Telemetry.here() do
		if row[3] == "session_start" then
			joined[row[2]] = row[1]
		end
	end
	local list = {}
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player) :: any
		local step, stepName = 0, nil
		if profile and type(profile.Funnel) == "table" then
			for i, name in require(script.Parent.Funnel).Steps do
				if profile.Funnel[name] then
					step, stepName = i, name
				end
			end
		end
		local state = profile and type(profile.IntroRounds) == "table" and IntroRounds.state(profile) or nil
		local since = joined[player.UserId]
		table.insert(list, {
			UserId = player.UserId,
			Excluded = DevAccounts.excluded(player),
			Listed = DevAccounts.listed()[player.UserId] == true or (profile ~= nil and profile.DevBackup ~= nil),
			Name = player.DisplayName,
			User = player.Name,
			Minutes = if since then math.floor((now - since) / 60) else nil,
			New = profile ~= nil and type(profile.Funnel) == "table",
			Step = step,
			StepName = stepName,
			Rounds = if state then state.Won else nil,
			Level = player:GetAttribute("MinerLevel"),
			Where = player:GetAttribute("CombatSession") or (if player:GetAttribute("MatchId") then "Match" else nil),
		})
	end
	table.sort(list, function(a, b)
		return (a.Minutes or 0) < (b.Minutes or 0)
	end)
	return list
end

function AnalyticsPanel.request(player: Player, range: any)
	if not DevAlerts.owner(player.UserId) then
		return reply(false, "Analytics are for the game's owners.")
	end
	if range == "Server" then
		local rows = Telemetry.here()
		return reply(true, "", {
			Range = "Server",
			Report = AnalyticsReport.build(rows, { Exclude = DevAccounts.listed() }),
			Here = here(),
			Since = Telemetry.Since,
			Server = Telemetry.Server,
			Now = os.time(),
		})
	end
	if range ~= "Today" and range ~= "Week" then
		return reply(false, "Unknown range.")
	end
	load(range)
	local loader = loaderOf(range)
	local done, total = progress(loader)
	return reply(true, "", {
		Range = range,
		Report = rangeReport(range),
		Loading = { Done = done, Total = total, Busy = loader.Busy },
		Problem = loader.Problem,
		Now = os.time(),
	})
end

-- An Owner marks a player here COUNTED or NOT COUNTED (Server.DevAccounts).
function AnalyticsPanel.exclude(player: Player, userId: any, excluded: any)
	if not DevAlerts.owner(player.UserId) then
		return reply(false, "Analytics are for the game's owners.")
	end
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	if not target then
		return reply(false, "They're not in this server.")
	end
	if not DevAccounts.set(target, excluded == true) then
		return reply(false, "Their profile is still loading.")
	end
	return reply(true, if excluded == true then target.DisplayName .. " is left out of the numbers." else target.DisplayName .. " counts again.")
end

local started = false
function AnalyticsPanel.start()
	if started then
		return
	end
	started = true
	Shop.register("AnalyticsReport", AnalyticsPanel.request)
	Shop.register("AnalyticsExclude", AnalyticsPanel.exclude)
	local function mark(player: Player)
		if DevAlerts.owner(player.UserId) then
			player:SetAttribute("AnalyticsOwner", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end

return AnalyticsPanel
