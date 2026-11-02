--[[
	Intro rounds, the server's side (the rules: Shared.IntroRounds).

	A new miner's 1v1 wins, the first fight and every round after it (or a
	queued Casual or Ranked 1v1 won anywhere), each roll the next piece of
	their set: Uncommon, or Rare, for the round's slot, given and put on at
	once, then their best build auto-equipped (bestBuild: gems into the gear
	and Q/E/R too). Round GemAfter also gives a gem (socketed by that), and
	the whole set pays SetCoins.

	Requests:
	  "IntroRoundNext"    the next round: the round's rival in a Training session
	                      (on the dungeon path once its 1v1s are won: { Dungeon
	                      = true }, and the client takes them to the dungeon)
	                      (Duelist.spawnRound; entering the Arena if need be)
	  "IntroRoundLeave"   done for now: out of the Arena to the Outpost (they
	                      can come back to it later from the PLAY menu)
	  "IntroRoundState"   -> IntroRounds.view: where their set stands

	The Social remote tells the client (Client.IntroRoundsUI):
	  "IntroRound", { Phase = "Won", Round, Piece = { Slot, Name, Rarity, Id },
	                  Reel = { { Name, Rarity } }, ReelLand (the card's roll),
	                  Gem?, Coins?, View }   a round won: the card, with the roll
	  "IntroRound", { Phase = "Lost", Round, View }   a round lost: try again?

	Player attributes:
	  IntroRounds      true while the card's up in the Arena (between rounds):
	                   the client's first-fight wait holds the lobby off for it
	  IntroRoundFight  the round being fought (Server.Duelist reads it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Config = require(ReplicatedStorage.Shared.Config)
local ExpandedTraits = require(ReplicatedStorage.Shared.ExpandedItemTraits)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
local Market = require(ReplicatedStorage.Shared.Market)
local RewardRoll = require(ReplicatedStorage.Shared.RewardRoll)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Analytics = require(script.Parent.Analytics)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local IntroRoundsServer = {}

local rng = Random.new()
local TIER = { Uncommon = 2, Rare = 3 }

-- The pieces a round can pay: `slot`'s gear at `rarity`, rollable. The sword
-- round only swords (one hand: the shield stays on).
local pools = {}
local function pool(slot: string, rarity: string)
	local key = slot .. ":" .. rarity
	if pools[key] then
		return pools[key]
	end
	local list = {}
	local kind = Slots.Definitions[slot].Kind
	local tier = TIER[rarity] or 2
	local source = if kind == "Weapons" then ExpandedTraits.Catalog.Weapons else ArmorFamilies.Catalog[kind]
	for _, gear in source or {} do
		if type(gear) == "table" and gear.RarityTier == tier and ExpandedTraits.rollable(gear) then
			if kind ~= "Weapons" or gear.WeaponType == "Sword" then
				table.insert(list, gear)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	pools[key] = list
	return list
end
IntroRoundsServer._pool = pool -- (tests)

-- The card's roll (Client IntroRoundsUI): ReelLength pieces from the same
-- pools the round rolls from (Uncommon, a Rare at the odds), the one won at
-- ReelLand, where the strip stops. Names and rarities only.
IntroRoundsServer.ReelLength = 28
IntroRoundsServer.ReelLand = 24
function IntroRoundsServer.reel(slot: string, piece, random: Random?)
	local r = random or rng
	local uncommon, rare = pool(slot, "Uncommon"), pool(slot, "Rare")
	local reel = {}
	for i = 1, IntroRoundsServer.ReelLength do
		if i == IntroRoundsServer.ReelLand then
			reel[i] = { Name = piece.Name, Rarity = piece.Rarity }
		else
			local isRare = #rare > 0 and (#uncommon == 0 or r:NextNumber() < IntroRounds.RareChance + 0.1)
			local list = if isRare then rare else uncommon
			local gear = list[r:NextInteger(1, math.max(1, #list))]
			reel[i] = { Name = if gear then gear.Name else piece.Name, Rarity = if gear then (if isRare then "Rare" else "Uncommon") else piece.Rarity }
		end
	end
	return reel, IntroRoundsServer.ReelLand
end

-- Gives `player` a piece for `slot` at `rarity` and puts it on. Returns what
-- it was, or nil (nothing in the pool, or no room).
local function grant(player: Player, profile, slot: string, rarity: string)
	local list = pool(slot, rarity)
	if #list == 0 and rarity == "Rare" then
		rarity = "Uncommon"
		list = pool(slot, rarity)
	end
	local gear = list[rng:NextInteger(1, math.max(1, #list))]
	if not gear then
		return nil
	end
	local kind = Slots.Definitions[slot].Kind
	local key = Slots.freeKey(profile.Owned[kind] or {}, gear.Id)
	local item = {
		Kind = "Gear",
		Slot = slot,
		Id = gear.Id,
		Quality = RewardRoll.quality(rarity),
		Roll = GearRolls.roll(rng, gear.RarityTier, gear),
	}
	if not Market.give(profile, item, math.huge, true) then
		return nil
	end
	pcall(GearRolls.ensure, profile, rng)
	PlayerData.equipGear(player, kind, key)
	return { Slot = slot, Name = gear.Name, Rarity = rarity, Id = gear.Id }
end

-- Their best build, put on for them after a round (the AUTO EQUIP button's
-- Best plan, Shared.AutoEquip): the gear, and gems into the gear, the
-- round's gem too; but a stone already in the sword, chest or shield (Q, E,
-- R: GemTraits) stays, so a new piece there keeps the same abilities (the
-- slot's stone goes onto the new piece: PlayerData.equipGear). The server does it, as you can't change your build
-- by hand mid-session in the Arena. Each gem counts as one socketed by hand
-- (Server.Forge.counted: Tasks, the funnel). Your skins are left as they are.
-- Returns gear pieces and gems changed.
function IntroRoundsServer.bestBuild(player: Player, profile): (number, number)
	local AutoEquip = require(ReplicatedStorage.Shared.AutoEquip)
	local plan = AutoEquip.plan(profile, "Best")
	local pieces, gems = 0, 0
	for _, step in plan.Gear or {} do
		if PlayerData.equipGear(player, Slots.Definitions[step.Slot].Kind, step.Id) then
			pieces += 1
		end
	end
	local Forge = nil
	local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
	for _, step in plan.Gems or {} do
		-- (The sword's, chest's and shield's stones are your Q, E and R: a
		-- stone already in one stays, so the intro's new piece keeps the same
		-- abilities. Only an empty one of them is filled.)
		if GemTraits.KeyOfSocket[step.Slot] and profile.Character[step.Slot .. "Gem"] ~= nil then
			continue
		end
		if PlayerData.socketGem(player, step.Gem, step.Slot) then
			gems += 1
			Forge = Forge or require(script.Parent.Forge)
			pcall(Forge.counted, player, step.Slot)
		end
	end
	return pieces, gems
end

-- The Intro Rounds funnel (Analytics.introStep): a round started (step
-- 2r - 1) or won (2r), each logged once a player (kept with the rounds).
function IntroRoundsServer.funnel(player: Player, state, round: number, won: boolean)
	if not state or round < 1 or round > IntroRounds.Count then
		return
	end
	local step = round * 2 - (if won then 0 else 1)
	state.Funnel = if type(state.Funnel) == "table" then state.Funnel else {}
	if state.Funnel[tostring(step)] then
		return
	end
	state.Funnel[tostring(step)] = true
	-- (a win counts its start too, for a round begun before the funnel was)
	if won and not state.Funnel[tostring(step - 1)] then
		state.Funnel[tostring(step - 1)] = true
		Analytics.introStep(player, step - 1)
	end
	Analytics.introStep(player, step)
end

local function stateOf(player: Player)
	local profile = PlayerData.get(player)
	return IntroRounds.state(profile), profile
end

-- Has `player` rounds left to win?
function IntroRoundsServer.eligible(player: Player): boolean
	return IntroRounds.eligible(PlayerData.get(player))
end

-- A 1v1 won: the round's piece, if they're on their intro rounds. Returns the
-- piece given, or nil (not theirs, or done).
-- On the dungeon path (Shared.IntroRounds' stage): every player once
-- Config.Features.IntroDungeon is on, the Owners always (to test it).
function IntroRoundsServer.dungeonPath(player: Player): boolean
	if Config.Features and Config.Features.IntroDungeon == true then
		return true
	end
	local owners = Config.Playtest and Config.Playtest.Owners or {}
	return table.find(owners, player.UserId) ~= nil
end

-- Where `player`'s intro is: "Duel", "Dungeon" or "Done" (nil: not a new miner's).
function IntroRoundsServer.stage(player: Player): string?
	local state = stateOf(player)
	if not state then
		return nil
	end
	return IntroRounds.stage(state, IntroRoundsServer.dungeonPath(player))
end

-- A moment in the intro dungeon (Server.Dungeons): its first room cleared
-- ("Room") or its boss down ("Boss"). Pays its pieces, a roll card each
-- (More: how many more are coming after this one). Returns how many.
function IntroRoundsServer.dungeonWon(player: Player, where: string): number
	local state = stateOf(player)
	local count = IntroRounds.dungeonPieces(state, where)
	local paid = 0
	for i = 1, count do
		if not IntroRoundsServer.won(player, "Dungeon", count - i) then
			break
		end
		paid += 1
	end
	return paid
end

function IntroRoundsServer.won(player: Player, where: string?, more: number?)
	local state, profile = stateOf(player)
	if not state or state.Won >= IntroRounds.Count then
		return nil
	end
	local round = IntroRounds.round(state)
	local slot = IntroRounds.slot(round)
	local piece = grant(player, profile, slot, IntroRounds.rarity(state, rng:NextNumber()))
	if not piece then
		warn("[IntroRounds] couldn't give round " .. round .. "'s " .. slot)
		player:SetAttribute("IntroRounds", nil)
		player:SetAttribute("IntroRoundFight", nil)
		Remotes.Notify:FireClient(player, "Your gear bag is full: make room, then win again for your intro piece.")
		return nil
	end
	IntroRoundsServer.funnel(player, state, round, true)
	IntroRounds.won(state, piece.Rarity)
	state.Pieces[slot] = { Name = piece.Name, Rarity = piece.Rarity }
	local event = { Phase = "Won", Round = round, Piece = piece, Where = where, More = more }
	-- (the dungeon path's last 1v1 won: next, the kaiju roll and the dungeon)
	if where ~= "Dungeon" and IntroRoundsServer.dungeonPath(player) and IntroRounds.stage(state, true) == "Dungeon" then
		event.Next = "Dungeon"
	end
	event.Reel, event.ReelLand = IntroRoundsServer.reel(slot, piece)
	-- Halfway: a gem too, to socket (the NEXT STEP card takes it from there).
	if round == IntroRounds.GemAfter then
		local GemGenerator = require(script.Parent.GemGenerator)
		local ok, gem = pcall(GemGenerator.generate, rng, "MiningStore", {
			Id = PlayerData.newGemId(),
			Time = os.time(),
			Rarity = "Uncommon",
		})
		if ok and gem and Market.give(profile, { Kind = "Gem", Gem = gem }, math.huge, true) then
			local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
			event.Gem = { Name = GemConfig.displayName(gem), Element = gem.Element }
		end
	end
	-- Then their best build on, gems and all (no trip to the Inventory).
	local ok, pieces, gems = pcall(IntroRoundsServer.bestBuild, player, profile)
	if ok and (pieces > 0 or gems > 0) then
		event.Auto = { Pieces = pieces, Gems = gems }
	elseif not ok then
		warn("[IntroRounds] auto equip failed: " .. tostring(pieces))
	end
	local done = state.Won >= IntroRounds.Count
	if done then
		PlayerData.addCoins(player, IntroRounds.SetCoins, "Tutorial")
		event.Coins = IntroRounds.SetCoins
	end
	Analytics.event(player, "IntroRound", round, slot, piece.Rarity, if done then "Done" else "Won")
	event.View = IntroRounds.view(state)
	player:SetAttribute("IntroRounds", if done then nil else true)
	player:SetAttribute("IntroRoundFight", nil)
	PlayerData.sync(player)
	Remotes.Social:FireClient(player, "IntroRound", event)
	return piece
end

-- A round lost: its next try is easier. Returns whether it was one.
function IntroRoundsServer.lost(player: Player): boolean
	local state = stateOf(player)
	if not state or state.Won >= IntroRounds.Count then
		return false
	end
	local round = IntroRounds.round(state)
	IntroRounds.lost(state)
	Analytics.event(player, "IntroRound", round, IntroRounds.slot(round), "Lost", "Lost")
	player:SetAttribute("IntroRounds", true)
	player:SetAttribute("IntroRoundFight", nil)
	Remotes.Social:FireClient(player, "IntroRound", { Phase = "Lost", Round = round, View = IntroRounds.view(state) })
	return true
end

local function nextRound(player: Player)
	local state = stateOf(player)
	if not state then
		return reply(false, "Your profile is still loading.")
	end
	if state.Won >= IntroRounds.Count then
		player:SetAttribute("IntroRounds", nil)
		return reply(false, "Your intro set is complete!")
	end
	if player:GetAttribute("MatchId") or player:GetAttribute("DuelQueue") then
		return reply(false, "You're already in a match.")
	end
	-- (The dungeon path, its 1v1s won: the dungeon's next. The client plays
	-- the kaiju roll, then goes in: Client FirstDungeonUI, "FirstDungeon".)
	if IntroRoundsServer.dungeonPath(player) and IntroRounds.stage(state, true) == "Dungeon" then
		return reply(true, "", { Dungeon = true })
	end
	local round = IntroRounds.round(state)
	-- (Always the round's rival: a new miner isn't sent into real players'
	-- queues till their set's done: Server.Duels' inIntro.)
	local Duelist = require(script.Parent.Duelist)
	player:SetAttribute("IntroRoundFight", round)
	player:SetAttribute("IntroRounds", true)
	local session = player:GetAttribute("CombatSession")
	if session == "Training" then
		if not Duelist.spawnRound(player) then
			player:SetAttribute("IntroRoundFight", nil)
			return reply(false, "Your rival isn't ready yet. Try again in a moment.")
		end
	elseif session == nil then
		-- (From the lobby: into the Arena, and its rival steps in: ArenaSessions.onEnter.)
		local result = require(script.Parent.ArenaSessions).enterTraining(player)
		if result and result.Ok == false then
			player:SetAttribute("IntroRoundFight", nil)
			player:SetAttribute("IntroRounds", nil)
			return result
		end
	else
		player:SetAttribute("IntroRoundFight", nil)
		return reply(false, "Leave your current fight first.")
	end
	IntroRoundsServer.funnel(player, state, round, false)
	return reply(true, string.format("Round %d of %d!", round, IntroRounds.Count), { Round = round })
end

local function leaveRounds(player: Player)
	player:SetAttribute("IntroRounds", nil)
	player:SetAttribute("IntroRoundFight", nil)
	if player:GetAttribute("CombatSession") == "Training" then
		return require(script.Parent.ArenaSessions).leave(player)
	end
	return reply(true, "Back to the Outpost.")
end

local started = false
function IntroRoundsServer.start()
	if started then
		return
	end
	started = true
	-- (Duels and Duelist call in here on a win or a lost round.)
	require(script.Parent.Duels).IntroRounds = IntroRoundsServer
	require(script.Parent.Duelist).IntroRounds = IntroRoundsServer
	Shop.register("IntroRoundNext", nextRound)
	Shop.register("IntroRoundLeave", leaveRounds)
	Shop.register("IntroRoundState", function(player: Player)
		local state = stateOf(player)
		return reply(true, "", { View = IntroRounds.view(state) })
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("IntroRounds", nil)
	end)
	-- Round 1 is the first fight: its start is the funnel's first step.
	local function watch(player: Player)
		player:GetAttributeChangedSignal("FirstFight"):Connect(function()
			if player:GetAttribute("FirstFight") == true then
				local state = stateOf(player)
				if state and state.Won == 0 then
					IntroRoundsServer.funnel(player, state, 1, false)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return IntroRoundsServer
