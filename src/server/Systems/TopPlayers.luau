--[[
	Top Players: global leaderboards for the best gem ever owned, monsters
	slain, Season level, gear score (Gear) and duel wins (Wins), and the
	Shelter's Hall of Fame (Shared.HallOfFame): 1v1 wins (Duel), 1v1 + Kaiju
	wins (Mixed, while Config.Features.KaijuDuel is on), Kaiju Arena wins (Kaiju), Rift bosses slain (Bosses) and
	gems mined (Mined). Each player's scores are written to ordered data
	stores every couple of minutes; the top ten are read back and cached.

	If data stores aren't available (e.g. Studio without API access), the
	boards rank the players in this server instead.

	Request action: "TopPlayers" -> { Global = bool, Boards = { Gem, Slain, Level } }
	where each board is a list of { Name, Value, UserId }.
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
local BOARDS = { "Gem", "Slain", "Level", "Gear", "Wins", "Duel", "Kaiju", "Bosses", "Mined" }
if Config.Features.KaijuDuel then
	table.insert(BOARDS, "Mixed")
end

local TopPlayers = {}

-- Never on a board: the game's own accounts (Config.Playtest's Owners and
-- Testers, and these usernames, any case). Their scores aren't written,
-- what's already there is taken off the next time they're in a server, and
-- rows of theirs are skipped when the boards are read.
TopPlayers.HiddenNames = { "Devvolver", "VolverDev" }

-- Whether `userId` (`name`: a username or display name) is kept off the boards.
function TopPlayers.hidden(userId: number?, name: string?): boolean
	local playtest = Config.Playtest or {}
	if userId and (table.find(playtest.Owners or {}, userId) or table.find(playtest.Testers or {}, userId)) then
		return true
	end
	local lower = string.lower(name or "")
	for _, hidden in TopPlayers.HiddenNames do
		if string.lower(hidden) == lower then
			return true
		end
	end
	return false
end

local function hiddenPlayer(player: Player): boolean
	return TopPlayers.hidden(player.UserId, player.Name) or TopPlayers.hidden(nil, player.DisplayName)
end

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { { Name: string, Value: number } } } = {}
local global = false
local names: { [number]: string } = {}
local removed: { [number]: boolean } = {} -- hidden accounts already taken off, this server

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
	local stats = profile.Stats :: any
	local duel = (profile :: any).Duel
	local bosses = 0
	for _, times in (profile :: any).RiftBosses or {} do
		bosses += tonumber(times) or 0
	end
	return {
		Gem = profile.Stats.BestGem,
		Slain = profile.Stats.Kills,
		Level = (Season.levelFor(profile.Season.XP)),
		Gear = GearRolls.gearScore(profile.Character),
		Wins = duel and duel.Wins or 0,
		Duel = duel and (duel.Solo or duel.Wins) or 0,
		Mixed = stats.MixedWins or 0,
		Kaiju = stats.KaijuWins or 0,
		Bosses = bosses,
		Mined = stats.GemsMined or 0,
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
			local s = not hiddenPlayer(player) and scores(player)
			if s then
				table.insert(rows, { Name = player.DisplayName, Value = s[board], UserId = player.UserId })
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
	-- Write everyone's scores (the hidden ones' taken off), then read the top ten.
	for _, player in Players:GetPlayers() do
		if hiddenPlayer(player) then
			if not removed[player.UserId] then
				removed[player.UserId] = true
				for _, board in BOARDS do
					pcall(stores[board].RemoveAsync, stores[board], tostring(player.UserId))
				end
			end
			continue
		end
		local s = scores(player)
		if s then
			for _, board in BOARDS do
				pcall(stores[board].SetAsync, stores[board], tostring(player.UserId), math.floor(s[board]))
			end
		end
	end
	local anyRead = false
	for _, board in BOARDS do
		local ok, pages = pcall(stores[board].GetSortedAsync, stores[board], false, 10 + #TopPlayers.HiddenNames + 2)
		if ok and pages then
			anyRead = true
			local rows = {}
			for _, entry in pages:GetCurrentPage() do
				local userId = tonumber(entry.key) or 0
				local name = nameOf(userId)
				if #rows < 10 and not TopPlayers.hidden(userId, name) then
					table.insert(rows, { Name = name, Value = entry.value, UserId = userId })
				end
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

-- A board's top rows ({ Name, Value, UserId }), best first (e.g. for the
-- Shelter's Hall of Fame).
function TopPlayers.board(name: string)
	if not global then
		localBoards()
	end
	return cache[name] or {}
end

-- Whether the boards are every server's (else this server's players).
function TopPlayers.isGlobal(): boolean
	return global
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
