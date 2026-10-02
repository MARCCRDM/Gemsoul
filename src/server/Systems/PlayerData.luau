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

local Classes = require(ReplicatedStorage.Shared.Classes)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local TestAdmin = require(script.Parent.TestAdmin)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Economy = require(ReplicatedStorage.Shared.ExpeditionEconomy)
local TradeJournal = require(script.Parent.TradeJournal)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Season = require(ReplicatedStorage.Shared.Season)
local Remotes = require(script.Parent.Remotes)

type Gem = GemConfig.Gem
type Character = {
	Class: string?,
	Weapon: string?,
	Armor: string?,
	WeaponGem: Gem?, -- a cut gem socketed into the weapon
	ArmorGem: Gem?, -- a cut gem socketed into the armor
	RigManeuvers: { string }?, -- the three rigManeuver ids on Q / E / R (Classes.loadout)
	WeaponQuality: number?, -- 1-4, see Crafting.Qualities
	ArmorQuality: number?,
	[string]: any,
}
-- Gear the player has made or been given: gear id -> quality (1-4).
type Owned = { [string]: { [string]: number } }
type Intro = { Spun: boolean, FirstStone: boolean, Done: boolean }
type Profile = {
	Augments: { [string]: any },
	Version: number,
	Coins: number,
	Marks: number, -- Guild Marks: from selling stones, spent in the Crafting Hall
	Gems: { Gem },
	Quota: { Day: number, UsedToday: number, Week: number, UsedThisWeek: number },
	Character: Character,
	Intro: Intro,
	Materials: { [string]: number }, -- crafting materials by id (see Crafting.Materials)
	Owned: Owned,
	-- Firsts that guide new players: "Mined", "Cut", "Sold", "Crafted", "Enchanted".
	Milestones: { [string]: boolean },
	Daily: { Day: number, Streak: number }, -- daily reward
	Cosmetics: { Owned: { [string]: boolean }, Trim: string?, Back: string? },
	Season: { XP: number, Claimed: { [string]: boolean } }, -- claimed levels, as strings
	Stats: { Kills: number, BestGem: number, BestDepth: number? }, -- for Top Players
	Crates: { [string]: number }, -- unopened crates
	Boosts: { XPUntil: number }, -- os.time() when 2x XP ends
	FirstJoin: number, -- os.time(); 0 for players from before the Welcome Bundle
	WelcomeBought: boolean,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}
local saving, tradeLocks, tradeReady = {}, {}, {}

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
	local profile = {
		Version = 10,
		Augments = {},
		Coins = Config.StartingCoins,
		Marks = 0,
		Gems = {},
		Quota = { Day = 0, UsedToday = 0, Week = 0, UsedThisWeek = 0 },
		Character = {},
		Intro = { Spun = false, FirstStone = false, Done = false },
		Materials = {},
		Owned = { Weapons = {}, Armors = {} },
		Milestones = {},
		Daily = { Day = 0, Streak = 0 },
		Cosmetics = { Owned = {} },
		Season = { XP = 0, Claimed = {} },
		Stats = { Kills = 0, BestGem = 0 },
		Crates = {},
		Boosts = { XPUntil = 0 },
		FirstJoin = os.time(),
		WelcomeBought = false,
	}
	Tree.initialize(profile)
	return profile
end

-- Brings profiles saved by older versions of the game up to date.
local function migrate(profile: Profile): Profile
	if (profile.Version or 1) < 2 then
		profile.Character = profile.Character or {}
		profile.Intro = profile.Intro or { Spun = false, FirstStone = false, Done = false }
		profile.Version = 2
	end
	if profile.Version < 3 then
		-- Crafting arrives: the gear you already wear counts as owned.
		profile.Materials = profile.Materials or {}
		local owned = { Weapons = {}, Armors = {} }
		local character = profile.Character
		if character.Weapon then
			owned.Weapons[character.Weapon] = 1
			character.WeaponQuality = 1
		end
		if character.Armor then
			owned.Armors[character.Armor] = 1
			character.ArmorQuality = 1
		end
		profile.Owned = owned
		profile.Version = 3
	end
	if profile.Version < 4 then
		profile.Marks = profile.Marks or 0
		profile.Version = 4
	end
	if profile.Version < 5 then
		-- Work out what returning players have already done, so the guide
		-- doesn't send them back to the quarry.
		local done = {}
		for _, gem in profile.Gems do
			done.Mined = done.Mined or gem.Source == "MiningNode" or gem.Source == "VipMiningNode"
			done.Cut = done.Cut or gem.CutMethod == "Manual" or gem.CutMethod == "AutoCut"
		end
		done.Mined = done.Mined or profile.Quota.UsedThisWeek > 0
		done.Sold = profile.Marks > 0
		for _, kind in { "Weapons", "Armors" } do
			local count = 0
			for _, quality in profile.Owned[kind] do
				count += 1
				done.Crafted = done.Crafted or quality > 1
			end
			done.Crafted = done.Crafted or count > 1
		end
		done.Enchanted = profile.Character.WeaponGem ~= nil or profile.Character.ArmorGem ~= nil
		profile.Milestones = profile.Milestones or {}
		for name, value in done do
			if value then
				profile.Milestones[name] = true
			end
		end
		profile.Daily = profile.Daily or { Day = 0, Streak = 0 }
		profile.Version = 5
	end
	if profile.Version < 6 then
		profile.Cosmetics = profile.Cosmetics or { Owned = {} }
		profile.Season = profile.Season or { XP = 0, Claimed = {} }
		profile.Stats = profile.Stats or { Kills = 0, BestGem = 0 }
		profile.Crates = profile.Crates or {}
		profile.Boosts = profile.Boosts or { XPUntil = 0 }
		-- The Welcome Bundle is for players who join from now on.
		profile.FirstJoin = profile.FirstJoin or 0
		profile.WelcomeBought = profile.WelcomeBought or false
		profile.Version = 6
	end
	if profile.Version < 7 then
		-- Armor became a ladder with a starter set: the free Iron Plate the
		-- old intro handed out becomes the starter Padded Jack. Plate that
		-- was upgraded at the forge is kept.
		local armors = profile.Owned.Armors
		if armors.IronPlate == 1 then
			armors.IronPlate = nil
			armors.PaddedJack = 1
			if profile.Character.Armor == "IronPlate" then
				profile.Character.Armor = "PaddedJack"
				profile.Character.ArmorQuality = 1
			end
		end
		profile.Version = 7
	end
	if profile.Version < 8 then
		-- Saga Miners: everyone gets the Saga Pistol & Shield, the new starter
		-- kit, and wears it instead of the free starter sword.
		local weapons = profile.Owned.Weapons
		weapons.PistolShield = weapons.PistolShield or 1
		if
			profile.Character.Class == "Warrior"
			and profile.Character.Weapon == "Longsword"
			and weapons.Longsword == 1
		then
			profile.Character.Weapon = "PistolShield"
			profile.Character.WeaponQuality = weapons.PistolShield
		end
		profile.Version = 8
	end
	Slots.initialize(profile)
	profile.Version = math.max(profile.Version, 10)
	Tree.initialize(profile)
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
		leaderstats.Marks.Value = profile.Marks
		leaderstats.Gems.Value = #profile.Gems
	end
	player:SetAttribute("MinedToday", profile.Quota.UsedToday)
	player:SetAttribute("DailyQuota", Config.DailyQuota)
	player:SetAttribute("MinedThisWeek", profile.Quota.UsedThisWeek)
	player:SetAttribute("WeeklyQuota", Config.WeeklyQuota)
	Remotes.Profile:FireClient(player, PlayerData.snapshot(player))
end

-- Saves with UpdateAsync, retrying a couple of times if Roblox is busy.
local function save(player: Player)
	local profile = profiles[player]
	if not profile or not canSave[player] or not store or saving[player] then
		return false
	end
	saving[player] = true
	local applied = table.clone(profile.AppliedEquipmentTrades or {})
	for attempt = 1, 3 do
		local ok, err = pcall(store.UpdateAsync, store, "player_" .. player.UserId, function()
			return profile
		end)
		if ok then
			TradeJournal.checkpoint(player.UserId, applied)
			saving[player] = nil
			tradeReady[player] = true
			return true
		end
		warn(("[PlayerData] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
	saving[player] = nil
	return false
end

-- Coins for coming back each day; the streak (up to a week) pays more.
local function claimDaily(player: Player, profile: Profile)
	local daily = profile.Daily
	local day = today()
	if daily.Day == day then
		return
	end
	daily.Streak = if daily.Day == day - 1 then math.min(daily.Streak + 1, Config.DailyStreakMax) else 1
	daily.Day = day
	local reward = Config.DailyRewardBase + Config.DailyRewardPerStreak * (daily.Streak - 1)
	profile.Coins += reward
	profile.Season.XP += Season.XP.Daily
	Tree.addXP(profile, Season.XP.Daily)
	Remotes.Notify:FireClient(
		player,
		string.format("Daily reward: +%d coins (day %d streak). Come back tomorrow for more!", reward, daily.Streak)
	)
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
	if loaded and not TradeJournal.recover(player.UserId, profiles[player]) then
		loaded = false
	end
	canSave[player] = loaded

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Coins", "Marks", "Gems" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	claimDaily(player, profiles[player])
	-- One class for now (Config.OnlyClass): anyone without it gets it, with
	-- its starter weapon and armor.
	local only = Config.OnlyClass
	if only and profiles[player].Character.Class ~= only then
		local class = Classes.get(only)
		if class then
			local character = profiles[player].Character
			character.Class = only
			character.Weapon = character.Weapon or class.Weapons[1].Id
			character.Armor = character.Armor or class.Armors[1].Id
			-- Family identity is equipped gear, never a saved subclass selection.
			character.Subclass, character.SubClass, character.Spec = nil, nil, nil
		end
	end
	Economy.migrate(profiles[player], Random.new())
	if only then
		profiles[player].Character.Subclass = nil
		profiles[player].Character.SubClass = nil
		profiles[player].Character.Spec = nil
		profiles[player].Character["Abilities"] = nil -- discard retired saved picks
		profiles[player].Character.RigManeuvers = nil
	end
	local currentProfile = profiles[player]
	local class = Classes.get(currentProfile.Character.Class)
	if class then
		GearRolls.grant(currentProfile, class, Random.new())
	end
	if loaded then
		save(player)
	end
	sync(player)
	characterChanged:Fire(player)
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
		tradeLocks[player] = nil
		tradeReady[player] = nil
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
		Augments = profile.Augments,
		Coins = profile.Coins,
		Marks = profile.Marks,
		Gems = profile.Gems,
		Quota = profile.Quota,
		DailyQuota = Config.DailyQuota,
		WeeklyQuota = Config.WeeklyQuota,
		Saving = canSave[player] == true,
		Character = profile.Character,
		Intro = profile.Intro,
		Materials = profile.Materials,
		Owned = profile.Owned,
		Milestones = profile.Milestones,
		Daily = profile.Daily,
		Cosmetics = profile.Cosmetics,
		Season = profile.Season,
		Stats = profile.Stats,
		Crates = profile.Crates,
		Boosts = profile.Boosts,
		FirstJoin = profile.FirstJoin,
		WelcomeBought = profile.WelcomeBought,
		ServerTime = os.time(),
		CanRegenerateEquipment = TestAdmin.allowed(player.UserId),
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
local SOCKET_KEYS = {}
for _, slot in Slots.Order do
	SOCKET_KEYS[slot] = slot .. "Gem"
end

function PlayerData.setLoadout(player: Player, classId: string, weaponId: string, armorId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	local character = profile.Character
	if character.Class ~= classId then
		local returned = {}
		for _, gems in character.ItemGems or {} do
			for _, gem in gems do
				if not returned[gem.Id] then
					table.insert(profile.Gems, gem)
					returned[gem.Id] = true
				end
			end
		end
		local sockets: { [string]: any } = character
		for _, key in SOCKET_KEYS do
			local gem = sockets[key]
			if gem and not returned[gem.Id] then
				table.insert(profile.Gems, gem)
				returned[gem.Id] = true
			end
			sockets[key] = nil
		end
		character.ItemGems = {}
	end
	character.Class, character.Weapon, character.Armor = classId, weaponId, armorId
	-- Picking gear in the intro gives you just those two pieces.
	profile.Owned = { Weapons = { [weaponId] = 1 }, Armors = { [armorId] = 1 } }
	character.WeaponQuality, character.ArmorQuality = 1, 1
	Slots.initialize(profile)
	GearRolls.grant(profile, Classes.get(classId), Random.new())
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
	if not profile or not key or not profile.Character[slot or "Weapon"] then
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
	local slotName = slot or "Weapon"
	profile.Character.ItemGems[slotName][profile.Character[slotName]] = gem
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
	profile.Character.ItemGems[slot][profile.Character[slot]] = nil
	table.insert(profile.Gems, gem)
	sync(player)
	characterChanged:Fire(player)
	return gem
end

-- The three rig maneuvers on Q / E / R (validated by the caller).
function PlayerData.setRigManeuvers(player: Player, ids: { string })
	local profile = profiles[player]
	if profile then
		profile.Character.RigManeuvers = ids
		sync(player)
	end
end

-- Wears (or with nil, removes) a trim or back piece; ownership is checked by the caller.
function PlayerData.setCosmetic(player: Player, kind: string, id: string?)
	local profile = profiles[player]
	if profile then
		(profile.Cosmetics :: any)[kind] = id
		sync(player)
		characterChanged:Fire(player)
	end
end

local GEAR_KEYS = Slots.ByKind

-- Wears a piece of gear you own ("Weapons" or "Armors", gear id).
function PlayerData.equipGear(player: Player, kind: string, gearId: string): boolean
	local profile = profiles[player]
	local key = GEAR_KEYS[kind]
	local quality = profile and key and profile.Owned[kind][gearId]
	if not profile or not quality then
		return false
	end
	local character: { [string]: any } = profile.Character
	character.ItemGems = character.ItemGems or {}
	character.ItemGems[key] = character.ItemGems[key] or {}
	if character[key] and character[key .. "Gem"] then
		character.ItemGems[key][character[key]] = character[key .. "Gem"]
	end
	character[key] = gearId
	character[key .. "Gem"] = character.ItemGems[key][gearId]
	character[key .. "Quality"] = quality
	sync(player)
	characterChanged:Fire(player)
	return true
end

-- Records recovered equipment and its quality.
function PlayerData.setGearQuality(player: Player, kind: string, gearId: string, quality: number)
	local profile = profiles[player]
	local key = GEAR_KEYS[kind]
	if not profile or not key then
		return
	end
	profile.Owned[kind][gearId] = quality
	GearRolls.ensure(profile, Random.new())
	local character: { [string]: any } = profile.Character
	if character[key] == gearId then
		character[key .. "Quality"] = quality
		characterChanged:Fire(player)
	end
	sync(player)
end

-- Records a first (see Profile.Milestones). Only syncs when it's new.
function PlayerData.milestone(player: Player, name: string)
	local profile = profiles[player]
	if profile and not profile.Milestones[name] then
		profile.Milestones[name] = true
		sync(player)
	end
end

function PlayerData.canTrade(player: Player): boolean
	return canSave[player] == true and tradeReady[player] == true
end
function PlayerData.setTradeLocked(player: Player, locked: boolean)
	tradeLocks[player] = if locked then true else nil
end
function PlayerData.isTradeLocked(player: Player): boolean
	return tradeLocks[player] == true
end
function PlayerData.suspendSaving(player: Player)
	canSave[player] = false
end
PlayerData.save = save

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

-- Guild Marks, the Crafting Hall's currency.
function PlayerData.spendMarks(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.Marks < amount then
		return false
	end
	profile.Marks -= amount
	sync(player)
	return true
end

function PlayerData.addMarks(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.Marks += amount
		sync(player)
	end
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

function PlayerData.augmentsChanged(player: Player)
	sync(player)
	characterChanged:Fire(player)
end

function PlayerData.sync(player: Player)
	sync(player)
end

return PlayerData
