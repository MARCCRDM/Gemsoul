--[[
	The Kaiju Daycare's server side (the rules: Shared.Daycare).

	  "DaycareState"                 -> { Entries, Home, Slots, Coins }
	  "DaycareBoard", id, mode, hours -> boards one of yours (STORE or TRAIN)
	  "DaycareCollect", entryId       -> pays and takes it back (trained)

	A boarded kaiju leaves the roster (Shared.Market.take, as one put up for
	sale: nothing can be boarded twice, or fight from the Daycare) and waits
	in profile.Daycare.Entries, saved with the profile. Collected, it comes
	back (Market.give: a new id, at the end of your line) with what it
	trained, at full health.

	The pen: ReplicatedStorage.DaycarePen holds one Configuration for every
	kaiju boarded by a player in this server (Species, Element, Level, Name,
	Owner, OwnerId, Mode), so everyone here sees them in it (Client.DaycarePen).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daycare = require(ReplicatedStorage.Shared.Daycare)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local Market = require(ReplicatedStorage.Shared.Market)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local DaycareServer = {}

local reply = Shop.reply
local pen: Folder? = nil

local function daycareOf(profile)
	local d = profile.Daycare
	if type(d) ~= "table" then
		d = { Entries = {}, Next = 1 }
		profile.Daycare = d
	end
	d.Entries = d.Entries or {}
	d.Next = d.Next or 1
	return d
end

-- The pen's view of `player`'s boarded kaiju (Client.DaycarePen).
local function publish(player: Player)
	if not pen then
		return
	end
	for _, child in pen:GetChildren() do
		if child:GetAttribute("OwnerId") == player.UserId then
			child:Destroy()
		end
	end
	local profile = player.Parent and PlayerData.get(player)
	if not profile then
		return
	end
	local now = os.time()
	for key, entry in daycareOf(profile).Entries do
		local record = entry.Record
		if type(record) == "table" then
			local result = Daycare.result(entry, now)
			local c = Instance.new("Configuration")
			c.Name = player.UserId .. "_" .. key
			c:SetAttribute("OwnerId", player.UserId)
			c:SetAttribute("Owner", player.DisplayName)
			c:SetAttribute("Species", record.Species)
			c:SetAttribute("Element", record.Element)
			c:SetAttribute("Level", result.Level)
			c:SetAttribute("Name", Kaiju.nameOf(record))
			c:SetAttribute("Mode", if entry.Mode == "Train" and not result.Done then "Train" else "Store")
			c.Parent = pen
		end
	end
end

-- An entry as the window shows it.
local function view(key: string, entry, now: number)
	local result = Daycare.result(entry, now)
	local record = entry.Record
	return {
		Key = key,
		Mode = entry.Mode,
		Hours = entry.Hours,
		At = entry.At,
		Name = Kaiju.nameOf(record),
		Species = record.Species,
		Element = record.Element,
		From = record.Level,
		Level = result.Level,
		Fee = result.Fee,
		Done = result.Done,
		Left = result.Left,
	}
end

function DaycareServer.state(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local now = os.time()
	local entries = {}
	for key, entry in daycareOf(profile).Entries do
		if type(entry.Record) == "table" then
			table.insert(entries, view(key, entry, now))
		end
	end
	table.sort(entries, function(a, b)
		return (a.At or 0) < (b.At or 0)
	end)
	-- The ones at home that could go in (not the team out, nor your support).
	local home = {}
	local roster = Kaiju.roster(profile)
	for _, id in Kaiju.order(roster) do
		local record = roster.List[id]
		if record and not Market.whyNot(profile, "Kaiju", nil, id) then
			table.insert(home, { Id = id, Name = Kaiju.nameOf(record), Species = record.Species, Element = record.Element, Level = record.Level, Down = record.Down == true })
		end
	end
	for id, record in roster.List do
		if Kaiju.isSupport(record.Species) and not table.find(Kaiju.order(roster), id) and not Market.whyNot(profile, "Kaiju", nil, id) then
			table.insert(home, { Id = id, Name = Kaiju.nameOf(record), Species = record.Species, Element = record.Element, Level = record.Level, Down = record.Down == true })
		end
	end
	return reply(true, "", {
		Entries = entries,
		Home = home,
		Slots = Daycare.Slots,
		Coins = profile.Coins,
		Owned = Kaiju.count(roster),
		MaxOwned = Kaiju.MaxOwned,
	})
end

function DaycareServer.board(player: Player, id: any, mode: any, hours: any)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	if not Daycare.Modes[mode] then
		return reply(false, "Store it or train it?")
	end
	if mode == "Train" and not table.find(Daycare.Stays, hours) then
		return reply(false, "Pick how long it trains.")
	end
	if player:GetAttribute("KaijuBattle") ~= nil then
		return reply(false, "Not in the middle of a kaiju battle.")
	end
	local why = Daycare.canBoard(profile, id)
	if why then
		return reply(false, why)
	end
	local roster = Kaiju.roster(profile)
	local record = roster.List[id]
	if record.Down then
		return reply(false, "It's knocked out: let it get back on its feet first.")
	end
	if mode == "Train" and record.Level >= Daycare.Train.Cap then
		return reply(false, string.format("It's level %d already: the Daycare trains up to level %d. Store it instead.", record.Level, Daycare.Train.Cap))
	end
	local payload = Market.take(profile, "Kaiju", nil, id)
	if not payload then
		return reply(false, "That kaiju can't go in right now.")
	end
	local d = daycareOf(profile)
	local key = "d" .. d.Next
	d.Next += 1
	d.Entries[key] = { Mode = mode, Hours = if mode == "Train" then hours else nil, At = os.time(), Record = payload.Record }
	PlayerData.sync(player)
	publish(player)
	return reply(
		true,
		if mode == "Train"
			then string.format("%s is training for %d hour%s.", Kaiju.nameOf(payload.Record), hours, if hours == 1 then "" else "s")
			else string.format("%s is stored at the Daycare.", Kaiju.nameOf(payload.Record)),
		{ Key = key }
	)
end

function DaycareServer.collect(player: Player, key: any)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local d = daycareOf(profile)
	local entry = type(key) == "string" and d.Entries[key]
	if not entry or type(entry.Record) ~= "table" then
		return reply(false, "That kaiju isn't at the Daycare.")
	end
	local roster = Kaiju.roster(profile)
	if Kaiju.count(roster) >= Kaiju.MaxOwned then
		return reply(false, string.format("You have %d kaiju already: make room first (LET GO or sell one).", Kaiju.MaxOwned))
	end
	local result = Daycare.result(entry, os.time())
	if (profile.Coins or 0) < result.Fee then
		return reply(false, string.format("Its fee is %d coins: you have %d.", result.Fee, profile.Coins or 0), { Short = result.Fee - (profile.Coins or 0) })
	end
	if result.Fee > 0 and not PlayerData.spendCoins(player, result.Fee, "Daycare") then
		return reply(false, "That didn't go through. Try again in a moment.")
	end
	local record = entry.Record
	local from = record.Level
	record.Level, record.Exp = result.Level, result.Exp
	record.Health = nil -- (full: Kaiju.health)
	record.Down, record.DownUntil = nil, nil
	d.Entries[key] = nil
	Market.give(profile, { Kind = "Kaiju", Record = record }, 0, true)
	PlayerData.sync(player)
	publish(player)
	local name = Kaiju.nameOf(record)
	return reply(
		true,
		if result.Level > from
			then string.format("%s is back, level %d (from %d), for %d coins.", name, result.Level, from, result.Fee)
			else string.format("%s is back, for %d coins.", name, result.Fee),
		{ Level = result.Level, Fee = result.Fee }
	)
end

local started = false
function DaycareServer.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "DaycarePen"
	folder.Parent = ReplicatedStorage
	pen = folder
	Shop.register("DaycareState", DaycareServer.state)
	Shop.register("DaycareBoard", DaycareServer.board)
	Shop.register("DaycareCollect", DaycareServer.collect)
	-- Who's in the pen: each player's, once their profile's in, and kept
	-- up to date (a level trained, a training done) every minute.
	local function joined(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				if not player.Parent or PlayerData.get(player) then
					break
				end
				task.wait(1)
			end
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, child in folder:GetChildren() do
			if child:GetAttribute("OwnerId") == player.UserId then
				child:Destroy()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				pcall(publish, player)
			end
		end
	end)
end

DaycareServer._publish = publish -- (tests)
return DaycareServer
