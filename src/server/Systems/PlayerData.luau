--[[
	Each player's saved profile: coins, gem inventory, free-mining quota,
	chosen class and gear, and progress through the intro.
	Loads from a DataStore on join and saves on leave, on shutdown and every
	few minutes. If loading fails (for example in Studio without API access)
	the player gets a fresh profile that is not saved, so a failed load can
	never overwrite real progress.

	Other systems change profiles only through this module, which keeps the
	leaderboard, attributes and the client's copy in sync.
]]
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Remotes = require(script.Parent.Remotes)

type Gem = GemConfig.Gem
type Character = {
	Class: string?,
	Weapon: string?,
	Armor: string?,
	WeaponGem: Gem?, -- a cut gem socketed into the weapon
	ArmorGem: Gem?, -- a cut gem socketed into the armor
}
type Intro = { Spun: boolean, FirstStone: boolean, Done: boolean }
type Profile = {
	Version: number,
	Coins: number,
	Gems: { Gem },
	Quota: { Day: number, UsedToday: number, Week: number, UsedThisWeek: number },
	Character: Character,
	Intro: Intro,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}

-- Fires (player) when a player's class, gear or socketed gem changes.
local characterChanged = Instance.new("BindableEvent")
PlayerData.CharacterChanged = characterChanged.Event

local store = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DataStoreName)
	if ok then
		store = result
	end
end

local function newProfile(): Profile
	return {
		Version = 2,
		Coins = Config.StartingCoins,
		Gems = {},
		Quota = { Day = 0, UsedToday = 0, Week = 0, UsedThisWeek = 0 },
		Character = {},
		Intro = { Spun = false, FirstStone = false, Done = false },
	}
end

-- Brings profiles saved by older versions of the game up to date.
local function migrate(profile: Profile): Profile
	if (profile.Version or 1) < 2 then
		profile.Character = profile.Character or {}
		profile.Intro = profile.Intro or { Spun = false, FirstStone = false, Done = false }
		profile.Version = 2
	end
	return profile
end

-- Days and weeks (starting Monday) since the Unix epoch, in UTC.
local function today(): number
	return math.floor(os.time() / 86400)
end
local function thisWeek(): number
	return math.floor((today() + 3) / 7)
end

local function resetQuotaIfNeeded(profile: Profile)
	local quota = profile.Quota
	if quota.Day ~= today() then
		quota.Day = today()
		quota.UsedToday = 0
	end
	if quota.Week ~= thisWeek() then
		quota.Week = thisWeek()
		quota.UsedThisWeek = 0
	end
end

-- Push the profile to the leaderboard, attributes and the owning client.
local function sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	resetQuotaIfNeeded(profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = profile.Coins
		leaderstats.Gems.Value = #profile.Gems
	end
	player:SetAttribute("MinedToday", profile.Quota.UsedToday)
	player:SetAttribute("DailyQuota", Config.DailyQuota)
	player:SetAttribute("MinedThisWeek", profile.Quota.UsedThisWeek)
	player:SetAttribute("WeeklyQuota", Config.WeeklyQuota)
	Remotes.Profile:FireClient(player, PlayerData.snapshot(player))
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return
	end
	local ok, err = pcall(store.SetAsync, store, "player_" .. player.UserId, profile)
	if not ok then
		warn("[PlayerData] Could not save " .. player.Name .. ": " .. tostring(err))
	end
end

local function load(player: Player)
	local profile, loaded = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(store.GetAsync, store, "player_" .. player.UserId)
			if ok then
				profile = if result then migrate(result) else newProfile()
				loaded = true
				break
			end
			warn(("[PlayerData] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			task.wait(attempt)
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = profile or newProfile()
	canSave[player] = loaded

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Coins", "Gems" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	sync(player)
	if not loaded then
		Remotes.Notify:FireClient(player, "Progress won't be saved this session (data storage unavailable).")
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

-- What the client sees of its own profile.
function PlayerData.snapshot(player: Player): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return {
		Coins = profile.Coins,
		Gems = profile.Gems,
		Quota = profile.Quota,
		DailyQuota = Config.DailyQuota,
		WeeklyQuota = Config.WeeklyQuota,
		Saving = canSave[player] == true,
		Character = profile.Character,
		Intro = profile.Intro,
	}
end

function PlayerData.character(player: Player): Character?
	local profile = profiles[player]
	return profile and profile.Character
end

function PlayerData.intro(player: Player): Intro?
	local profile = profiles[player]
	return profile and profile.Intro
end

-- Records a step of the intro (e.g. "Spun", "FirstStone", "Done").
function PlayerData.setIntroFlag(player: Player, flag: string)
	local profile = profiles[player]
	if profile then
		(profile.Intro :: any)[flag] = true
		sync(player)
	end
end

-- Sets class, weapon and armor (ids are checked by the caller).
local SOCKET_KEYS = { Weapon = "WeaponGem", Armor = "ArmorGem" }

function PlayerData.setLoadout(player: Player, classId: string, weaponId: string, armorId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	local character = profile.Character
	if character.Class ~= classId then
		-- Changing class puts socketed gems back in the pouch.
		local sockets: { [string]: any } = character
		for _, key in SOCKET_KEYS do
			if sockets[key] then
				table.insert(profile.Gems, sockets[key])
				sockets[key] = nil
			end
		end
	end
	character.Class, character.Weapon, character.Armor = classId, weaponId, armorId
	sync(player)
	characterChanged:Fire(player)
end

--[[
	Moves a cut gem from the pouch into the weapon's or armor's socket. A gem
	already in that socket goes back to the pouch. Returns the socketed gem.
]]
function PlayerData.socketGem(player: Player, gemId: string, slot: string?): Gem?
	local profile = profiles[player]
	local key = SOCKET_KEYS[slot or "Weapon"]
	if not profile or not key or not profile.Character[if slot == "Armor" then "Armor" else "Weapon"] then
		return nil
	end
	local gem = PlayerData.findGem(player, gemId)
	if not gem or gem.Cut == nil then
		return nil
	end
	PlayerData.removeGem(player, gemId)
	local sockets: { [string]: any } = profile.Character
	if sockets[key] then
		table.insert(profile.Gems, sockets[key])
	end
	sockets[key] = gem
	sync(player)
	characterChanged:Fire(player)
	return gem
end

-- Takes the gem out of a socket and back into the pouch, if there's room.
function PlayerData.unsocketGem(player: Player, slot: string): Gem?
	local profile = profiles[player]
	local key = SOCKET_KEYS[slot]
	if not profile or not key then
		return nil
	end
	local sockets: { [string]: any } = profile.Character
	local gem = sockets[key]
	if not gem or #profile.Gems >= Config.MaxGems then
		return nil
	end
	sockets[key] = nil
	table.insert(profile.Gems, gem)
	sync(player)
	characterChanged:Fire(player)
	return gem
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.findGem(player: Player, gemId: string): Gem?
	local profile = profiles[player]
	if profile then
		for _, gem in profile.Gems do
			if gem.Id == gemId then
				return gem
			end
		end
	end
	return nil
end

function PlayerData.newGemId(): string
	return HttpService:GenerateGUID(false)
end

-- Adds a gem; returns false if the inventory is full.
function PlayerData.addGem(player: Player, gem: Gem): boolean
	local profile = profiles[player]
	if not profile or #profile.Gems >= Config.MaxGems then
		return false
	end
	table.insert(profile.Gems, gem)
	sync(player)
	return true
end

function PlayerData.removeGem(player: Player, gemId: string): Gem?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	for i, gem in profile.Gems do
		if gem.Id == gemId then
			table.remove(profile.Gems, i)
			sync(player)
			return gem
		end
	end
	return nil
end

-- Moves a fully generated gem between players (PvP wager settlement).
-- The gem keeps all its properties; its Source becomes "PvPWager".
function PlayerData.transferGem(from: Player, to: Player, gemId: string): boolean
	local target = profiles[to]
	if not target or #target.Gems >= Config.MaxGems then
		return false
	end
	local gem = PlayerData.removeGem(from, gemId)
	if not gem then
		return false
	end
	gem.Source = "PvPWager"
	return PlayerData.addGem(to, gem)
end

-- Marks a gem as changed (e.g. after cutting) so clients see it.
function PlayerData.gemChanged(player: Player)
	sync(player)
end

function PlayerData.spendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	sync(player)
	return true
end

function PlayerData.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.Coins += amount
		sync(player)
	end
end

-- Uses one free mine if any are left today and this week.
function PlayerData.useFreeMine(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	resetQuotaIfNeeded(profile)
	local quota = profile.Quota
	if quota.UsedToday >= Config.DailyQuota or quota.UsedThisWeek >= Config.WeeklyQuota then
		return false
	end
	quota.UsedToday += 1
	quota.UsedThisWeek += 1
	sync(player)
	return true
end

-- Gives back a free mine (if the reward couldn't be delivered).
function PlayerData.refundFreeMine(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Quota.UsedToday = math.max(0, profile.Quota.UsedToday - 1)
		profile.Quota.UsedThisWeek = math.max(0, profile.Quota.UsedThisWeek - 1)
		sync(player)
	end
end

function PlayerData.sync(player: Player)
	sync(player)
end

return PlayerData
