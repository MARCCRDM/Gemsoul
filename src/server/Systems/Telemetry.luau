--[[
	The game's own event log, in a DataStore of its own (Name), next to what
	goes to Roblox's Creator Dashboard (Analytics): every player's sessions,
	device, the onboarding funnel, the intro rounds, duels, coins in and out
	by reason, purchases (with the Robux spent), and everything else the game
	reports as a custom event. tools/telemetry pulls it out with Open Cloud
	and builds the dashboard (docs/telemetry.md).

	Each event is a row { t, u, e, v, a, b, c }: os.time(), the UserId, its
	name, a number, and up to three fields. A server keeps the hour's rows
	and saves them every FlushEvery seconds (and when it closes) under its own
	key for the hour:

	  ev/<YYYY-MM-DD>/<HH>/<server>          (UTC; <server>: its JobId's start)
	  ev/<YYYY-MM-DD>/<HH>/<server>-<n>      (more of that hour, past MaxRows)

	so no two servers ever write the same key. In Studio it's StudioName, so
	tests never mix with the real game's.

	What it records (besides the game's own events, by their names):
	  session_start   v: account age in days   a: "new" | "returning"   b: country
	  session_end     v: seconds played        a: level   b: coins   c: ping (ms)
	  device          a: "phone" | "tablet" | "desktop" | "console"   b: screen   c: locale
	  onboarding      v: step   a: its name                       (Server.Funnel)
	  store_funnel    v: step   a: its name                       (Analytics' Store funnel)
	  coins           v: +in / -out   a: reason   b: its kind     (Analytics' economy)
	  server          v: players in it   a: place version         (every flush)

	  Telemetry.start()
	  Telemetry.record(player | userId, name, value?, a?, b?, c?)
	  Telemetry.flush()               save now
	  Telemetry.key(time, server, n?) -> string   (pure)
	  Telemetry.here() -> rows        everything since this server started
	                                  (about the newest KeepHere; the ANALYTICS
	                                  window's THIS SERVER: Server.AnalyticsPanel)
	  Telemetry.store() -> DataStore? the log (nil if it can't be had)
	  Telemetry.Server, Telemetry.Since   this server's id, when it started
	  Telemetry.platform(info) -> string          (pure: a client's device report)
]]
local DataStoreService = game:GetService("DataStoreService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Telemetry = {}

Telemetry.Name = "SagaTelemetry_v1"
Telemetry.StudioName = "SagaTelemetry_Studio"
Telemetry.FlushEvery = 300 -- seconds between saves
Telemetry.MaxRows = 20000 -- rows under one key (well inside a DataStore entry's 4 MB)
Telemetry.Enabled = true
Telemetry.KeepHere = 40000 -- rows this server keeps in memory since it started

local SERVER = string.sub(string.gsub(game.JobId, "-", ""), 1, 8)
if SERVER == "" then
	SERVER = "studio"
end

-- The hour's key for a server.
function Telemetry.key(time: number, server: string, n: number?): string
	local base = "ev/" .. os.date("!%Y-%m-%d/%H", time) .. "/" .. server
	return if n and n > 1 then base .. "-" .. n else base
end

-- A client's device report, as a platform.
function Telemetry.platform(info): string
	if type(info) ~= "table" then
		return "unknown"
	end
	if info.Console or info.TenFoot then
		return "console"
	end
	if info.Touch and not info.Keyboard then
		local x, y = tonumber(info.X) or 0, tonumber(info.Y) or 0
		return if math.min(x, y) >= 600 then "tablet" else "phone"
	end
	return "desktop"
end

Telemetry.Server = SERVER
Telemetry.Since = os.time()

local rows = {} -- this hour's
local here = {} -- since this server started (Telemetry.here)
local hourKey = nil -- (the hour they belong to)
local part = 1
local dirty = false
local joined: { [Player]: number } = {}
local store = nil

local function storeOf()
	if store == nil then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, if RunService:IsStudio() then Telemetry.StudioName else Telemetry.Name)
		store = if ok then result else false
	end
	return store or nil
end
Telemetry.store = storeOf

function Telemetry.here()
	return here
end

local function clip(v: any): any
	if v == nil then
		return nil
	end
	if type(v) == "number" then
		return v
	end
	return string.sub(tostring(v), 1, 60)
end

-- Saves this hour's rows (all of them: the key is this server's alone).
function Telemetry.flush()
	if not dirty or not hourKey then
		return
	end
	local ds = storeOf()
	if not ds then
		return
	end
	dirty = false
	local key = Telemetry.key(hourKey, SERVER, part)
	local snapshot = table.clone(rows)
	local ok, problem = pcall(function()
		ds:SetAsync(key, { V = 1, Server = SERVER, Place = game.PlaceVersion, Rows = snapshot })
	end)
	if not ok then
		dirty = true -- (next time)
		warn("[Telemetry] couldn't save " .. key .. ": " .. tostring(problem))
	end
end

function Telemetry.record(who: any, name: string, value: number?, a: any?, b: any?, c: any?)
	if not Telemetry.Enabled or type(name) ~= "string" then
		return
	end
	local now = os.time()
	local hour = now - now % 3600
	if hourKey ~= hour then
		-- A new hour: the last one's saved for good, a new key starts.
		if hourKey then
			Telemetry.flush()
		end
		hourKey, part, rows = hour, 1, {}
	elseif #rows >= Telemetry.MaxRows then
		Telemetry.flush()
		part += 1
		rows = {}
	end
	local userId = if type(who) == "number" then who elseif who ~= nil then tonumber(who.UserId) or 0 else 0
	local row = { now, userId, string.sub(name, 1, 40), tonumber(value) or 1, clip(a), clip(b), clip(c) }
	table.insert(rows, row)
	table.insert(here, row)
	if #here > Telemetry.KeepHere + 2000 then
		-- (the oldest 2000 go, in one move)
		here = table.move(here, 2001, #here, 1, {})
	end
	dirty = true
end

local function sessionStart(player: Player)
	joined[player] = os.time()
	local PlayerData = require(script.Parent.PlayerData)
	local profile = PlayerData.get(player)
	local first = profile and tonumber(profile.FirstJoin) or 0
	local fresh = first > 0 and os.time() - first < 600
	local ok, country = pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
	Telemetry.record(player, "session_start", player.AccountAge, if fresh then "new" else "returning", if ok then country else "??")
end

local function sessionEnd(player: Player)
	local since = joined[player]
	joined[player] = nil
	if not since then
		return
	end
	local PlayerData = require(script.Parent.PlayerData)
	local profile = PlayerData.get(player)
	local ok, ping = pcall(player.GetNetworkPing, player)
	Telemetry.record(
		player,
		"session_end",
		os.time() - since,
		player:GetAttribute("MinerLevel"),
		profile and profile.Coins,
		if ok and type(ping) == "number" then math.floor(ping * 1000) else nil
	)
end

local started = false
function Telemetry.start(remote: RemoteEvent?)
	if started then
		return
	end
	started = true
	-- Everything the game sends Roblox's dashboard comes here too.
	local Analytics = require(script.Parent.Analytics)
	local send = Analytics.send
	local economy, custom, funnel = send.economy, send.custom, send.funnel
	send.economy = function(player, source, amount, balance, kind, sku)
		Telemetry.record(player, "coins", if source then amount else -amount, sku, kind)
		return economy(player, source, amount, balance, kind, sku)
	end
	send.custom = function(player, name, value, fields)
		local f = fields or {}
		local a, b, c = nil, nil, nil
		for key, v in f do
			if string.find(key, "01", 1, true) then
				a = v
			elseif string.find(key, "02", 1, true) then
				b = v
			elseif string.find(key, "03", 1, true) then
				c = v
			end
		end
		Telemetry.record(player, name, value, a, b, c)
		return custom(player, name, value, fields)
	end
	send.funnel = function(player, funnelName, session, step, stepName)
		Telemetry.record(player, "store_funnel", step, stepName, funnelName)
		return funnel(player, funnelName, session, step, stepName)
	end
	local Funnel = require(script.Parent.Funnel)
	local log = Funnel.log
	Funnel.log = function(player, step, name)
		Telemetry.record(player, "onboarding", step, name)
		return log(player, step, name)
	end
	-- Sessions.
	local PlayerData = require(script.Parent.PlayerData)
	PlayerData.Loaded:Connect(sessionStart)
	Players.PlayerRemoving:Connect(sessionEnd)
	-- The client's device, once a session.
	if remote then
		local told = {}
		remote.OnServerEvent:Connect(function(player, info)
			if told[player] or type(info) ~= "table" then
				return
			end
			told[player] = true
			local x, y = math.floor(tonumber(info.X) or 0), math.floor(tonumber(info.Y) or 0)
			Telemetry.record(player, "device", 1, Telemetry.platform(info), x .. "x" .. y, info.Locale)
		end)
		Players.PlayerRemoving:Connect(function(player)
			told[player] = nil
		end)
	end
	task.spawn(function()
		while true do
			task.wait(Telemetry.FlushEvery)
			Telemetry.record(0, "server", #Players:GetPlayers(), game.PlaceVersion)
			Telemetry.flush()
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			sessionEnd(player)
		end
		Telemetry.record(0, "server", 0, game.PlaceVersion, "closed")
		Telemetry.flush()
	end)
end

return Telemetry
