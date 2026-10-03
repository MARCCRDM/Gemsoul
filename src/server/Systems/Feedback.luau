--[[
	Playtest feedback and error reports, kept in a DataStore so you can read
	them later in game.

	  "SendFeedback", kind, text   a player's bug report or idea ("Bug" | "Idea")
	  "ReadReports"                owners only (Config.Playtest.Owners; anyone in
	                               Studio): the latest feedback and the most
	                               frequent errors
	  Remotes.Report "Error", message, trace   a client script error

	Server script errors are caught too (ScriptContext.Error). Errors are
	grouped by message and counted, then written once a minute. Every report
	carries the build (Config.Playtest.Build), so you know which version it
	came from.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local Feedback = {}

Feedback.MaxText = 600
Feedback.Cooldown = 20 -- seconds between one player's reports
Feedback.Keep = 200 -- feedback entries kept
Feedback.KeepErrors = 100 -- distinct errors kept

local store = nil
local lastSent: { [Player]: number } = {}
local clientErrors: { [Player]: { number } } = {} -- report times, for rate limits
local pendingErrors = {} -- [key] = { Message, Trace, Side, Count, Last }

local function build(): string
	return Config.Playtest and Config.Playtest.Build or "dev"
end

function Feedback.isOwner(player: Player): boolean
	local owners = Config.Playtest and Config.Playtest.Owners or {}
	return RunService:IsStudio() or table.find(owners, player.UserId) ~= nil
end

-- Pure: a cleaned report, or nil and why not.
function Feedback.clean(kind: any, text: any): ({ Kind: string, Text: string }?, string?)
	if kind ~= "Bug" and kind ~= "Idea" then
		return nil, "Pick Bug or Idea."
	end
	if type(text) ~= "string" then
		return nil, "Write something first."
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	if #trimmed < 3 then
		return nil, "Write a little more."
	end
	return { Kind = kind, Text = string.sub(trimmed, 1, Feedback.MaxText) }, nil
end

-- Pure: merges counted errors into a saved list, most frequent first.
function Feedback.mergeErrors(saved, pending, keep: number)
	local byKey = {}
	for _, entry in saved or {} do
		byKey[entry.Key] = entry
	end
	for key, entry in pending do
		local existing = byKey[key]
		if existing then
			existing.Count += entry.Count
			existing.Last = math.max(existing.Last, entry.Last)
			existing.Build = entry.Build
		else
			byKey[key] = {
				Key = key,
				Message = entry.Message,
				Trace = entry.Trace,
				Side = entry.Side,
				Count = entry.Count,
				Last = entry.Last,
				Build = entry.Build,
			}
		end
	end
	local list = {}
	for _, entry in byKey do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.Count > b.Count
	end)
	while #list > keep do
		table.remove(list)
	end
	return list
end

local function noteError(side: string, message: string, trace: string)
	message = string.sub(tostring(message), 1, 300)
	trace = string.sub(tostring(trace or ""), 1, 600)
	local key = side .. ":" .. message
	local entry = pendingErrors[key]
	if entry then
		entry.Count += 1
		entry.Last = os.time()
	else
		pendingErrors[key] =
			{ Message = message, Trace = trace, Side = side, Count = 1, Last = os.time(), Build = build() }
	end
end

local function flush()
	if not store or next(pendingErrors) == nil then
		return
	end
	local pending = pendingErrors
	pendingErrors = {}
	local ok = pcall(store.UpdateAsync, store, "errors", function(saved)
		return Feedback.mergeErrors(saved, pending, Feedback.KeepErrors)
	end)
	if not ok then
		-- Try again next time.
		for key, entry in pending do
			pendingErrors[key] = pendingErrors[key] or entry
		end
	end
end

local function send(player: Player, kind: any, text: any)
	local now = os.clock()
	if lastSent[player] and now - lastSent[player] < Feedback.Cooldown then
		return reply(false, "Thanks! Give it a few seconds before sending another.")
	end
	local report, problem = Feedback.clean(kind, text)
	if not report then
		return reply(false, problem or "Couldn't send that.")
	end
	if not store then
		return reply(false, "Feedback needs the published game (data storage is off here).")
	end
	lastSent[player] = now
	local entry = {
		Kind = report.Kind,
		Text = report.Text,
		UserId = player.UserId,
		Name = player.DisplayName,
		Build = build(),
		Time = os.time(),
		-- Where they were, to help reproduce it.
		Where = player:GetAttribute("MatchId") and "Duel"
			or player:GetAttribute("CombatSession")
			or (player:GetAttribute("Expedition") and "Expedition")
			or "Menu",
	}
	local ok = pcall(store.UpdateAsync, store, "feedback", function(saved)
		local list = saved or {}
		table.insert(list, 1, entry)
		while #list > Feedback.Keep do
			table.remove(list)
		end
		return list
	end)
	if not ok then
		return reply(false, "Couldn't save that right now. Try again in a moment.")
	end
	return reply(true, "Thanks! Your " .. string.lower(report.Kind) .. " report was sent.")
end

local function read(player: Player)
	if not Feedback.isOwner(player) then
		return reply(false, "Only the game's owners can read reports.")
	end
	flush()
	local feedback, errors = {}, {}
	if store then
		local okA, a = pcall(store.GetAsync, store, "feedback")
		local okB, b = pcall(store.GetAsync, store, "errors")
		feedback = if okA and a then a else {}
		errors = if okB and b then b else {}
	end
	local result = reply(true, "")
	result.Feedback = table.move(feedback, 1, math.min(#feedback, 60), 1, {})
	result.Errors = table.move(errors, 1, math.min(#errors, 40), 1, {})
	return result
end

function Feedback.start()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "Playtest_Reports_v1")
	store = if ok then result else nil
	Shop.register("SendFeedback", send)
	Shop.register("ReadReports", read)
	ScriptContext.Error:Connect(function(message, trace)
		noteError("Server", message, trace)
	end)
	Remotes.Report.OnServerEvent:Connect(function(player, kind, message, trace)
		if kind ~= "Error" or type(message) ~= "string" then
			return
		end
		-- At most 5 a minute from any one player.
		local now = os.clock()
		local times = clientErrors[player] or {}
		while times[1] and now - times[1] > 60 do
			table.remove(times, 1)
		end
		if #times >= 5 then
			return
		end
		table.insert(times, now)
		clientErrors[player] = times
		noteError("Client", message, if type(trace) == "string" then trace else "")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player], clientErrors[player] = nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			flush()
		end
	end)
	game:BindToClose(flush)
end

return Feedback
