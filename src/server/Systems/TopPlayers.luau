--[[
	Top Players: global leaderboards for the best gem ever owned, monsters
	slain, Season level, gear score (Gear) and duel wins (Wins). Each player's scores are written to ordered data
	stores every couple of minutes; the top ten are read back and cached.

	If data stores aren't available (e.g. Studio without API access), the
	boards rank the players in this server instead.

	Request action: "TopPlayers" -> { Global = bool, Boards = { Gem, Slain, Level } }
	where each board is a list of { Name, Value }.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Season = require(ReplicatedStorage.Shared.Season)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local REFRESH_SECONDS = 120
local BOARDS = { "Gem", "Slain", "Level", "Gear", "Wins" }

local TopPlayers = {}

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { { Name: string, Value: number } } } = {}
local global = false
local names: { [number]: string } = {}

-- A player's score on each board.
local function scores(player: Player): { [string]: number }?
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local best = 0
	local function consider(gem)
		if gem then
			best = math.max(best, GemConfig.value(gem))
		end
	end
	for _, gem in profile.Gems do
		consider(gem)
	end
	consider(profile.Character.WeaponGem)
	consider(profile.Character.ArmorGem)
	profile.Stats.BestGem = math.max(profile.Stats.BestGem, best)
	return {
		Gem = profile.Stats.BestGem,
		Slain = profile.Stats.Kills,
		Level = (Season.levelFor(profile.Season.XP)),
		Gear = GearRolls.gearScore(profile.Character),
		Wins = profile.Duel and profile.Duel.Wins or 0,
	}
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Player " .. userId
	return names[userId]
end

-- Ranks the players in this server (the fallback).
local function localBoards()
	for _, board in BOARDS do
		local rows = {}
		for _, player in Players:GetPlayers() do
			local s = scores(player)
			if s then
				table.insert(rows, { Name = player.DisplayName, Value = s[board] })
			end
		end
		table.sort(rows, function(a, b)
			return a.Value > b.Value
		end)
		cache[board] = rows
	end
end

local function refresh()
	if not global then
		localBoards()
		return
	end
	-- Write everyone's scores, then read the top ten.
	for _, player in Players:GetPlayers() do
		local s = scores(player)
		if s then
			for _, board in BOARDS do
				pcall(stores[board].SetAsync, stores[board], tostring(player.UserId), math.floor(s[board]))
			end
		end
	end
	local anyRead = false
	for _, board in BOARDS do
		local ok, pages = pcall(stores[board].GetSortedAsync, stores[board], false, 10)
		if ok and pages then
			anyRead = true
			local rows = {}
			for _, entry in pages:GetCurrentPage() do
				table.insert(rows, { Name = nameOf(tonumber(entry.key) or 0), Value = entry.value })
			end
			cache[board] = rows
		end
	end
	-- No access to the global boards (e.g. Studio): rank this server instead.
	if not anyRead then
		global = false
		localBoards()
	end
end

-- A board's top rows ({ Name, Value }), best first (e.g. for the Outpost's billboard).
function TopPlayers.board(name: string)
	if not global then
		localBoards()
	end
	return cache[name] or {}
end

function TopPlayers.start()
	global = true
	for _, board in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.DataStoreName .. "_Top_" .. board)
		if ok and store then
			stores[board] = store
		else
			global = false
		end
	end
	Shop.register("TopPlayers", function()
		if not global then
			localBoards()
		end
		return Shop.reply(true, "", { Global = global, Boards = cache })
	end)
	task.spawn(function()
		while true do
			local ok = pcall(refresh)
			if not ok then
				global = false
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return TopPlayers
