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
-- (HUNT BOUNTY picked, the kaiju roll first: IntroRoundsServer.huntPending)
local huntPending = {} :: { [Player]: boolean }
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
			reel[i] = { Name = piece.Name, Rarity = piece.Rarity, Id = piece.Id }
		else
			local isRare = #rare > 0 and (#uncommon == 0 or r:NextNumber() < IntroRounds.RareChance + 0.1)
			local list = if isRare then rare else uncommon
			local gear = list[r:NextInteger(1, math.max(1, #list))]
			reel[i] = {
				Name = if gear then gear.Name else piece.Name,
				Rarity = if gear then (if isRare then "Rare" else "Uncommon") else piece.Rarity,
				Id = if gear then gear.Id else piece.Id,
			}
		end
	end
	return reel, IntroRoundsServer.ReelLand
end

-- The reel's pictures: a 3D preview of every piece the set's rolls can show
-- (each slot's Uncommon and Rare pool: a few a slot), built on the server's
-- mannequin ahead of the card (Equipment.groupPreviews, group "R":
-- "Slot|R:<id>", drawn by the client's GearArt). Quietly, in the background,
-- a few tries if the mannequin's busy; once built they stay.
local warming = {} :: { [Player]: boolean }
IntroRoundsServer.ResumeAfter = 6 -- seconds after they're in before a rejoin goes back to its rounds
-- Never stuck in the intro's Arena (no way out of it mid-set): StuckAfter
-- seconds in it with rounds left and no rival, and the next round comes in
-- (the card's own countdown does it sooner); DoneOutAfter seconds in it with
-- the set done, and they're taken out to the finale.
IntroRoundsServer.StuckAfter = 25
IntroRoundsServer.DoneOutAfter = 45
IntroRoundsServer.ChoiceWait = 180 -- (after the first win: the kaiju roll, then the card's three ways on: time for both)
function IntroRoundsServer.warm(player: Player)
	if warming[player] then
		return
	end
	warming[player] = true
	task.spawn(function()
		local items = {}
		for _, slot in IntroRounds.Order do
			for _, rarity in { "Uncommon", "Rare" } do
				for _, gear in pool(slot, rarity) do
					items[gear.Id] = { Slot = slot, Id = gear.Id, Quality = RewardRoll.quality(rarity) }
				end
			end
		end
		local Equipment = require(script.Parent.Equipment)
		for _ = 1, 8 do
			if not player.Parent then
				break
			end
			local ok, done = pcall(Equipment.groupPreviews, player, "R", items)
			if ok and done then
				break
			end
			task.wait(1.5)
		end
		warming[player] = nil
	end)
end

-- Their round's rival, if it's up (Server.Duelist tags it RivalOwner).
local function rivalUp(player: Player): boolean
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:GetAttribute("RivalOwner") == player.UserId then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return true
			end
		end
	end
	return false
end
IntroRoundsServer._rivalUp = rivalUp

-- One look at `player` (the watch's): moves them on if they're stuck in
-- the intro's Arena. `since` remembers since when; returns what it did.
local stuckSince = {} :: { [Player]: number }
-- (the set won in this Arena visit: out by itself if nothing takes them,
-- whatever's next; later practice is never cut short)
local setDone = {} :: { [Player]: boolean }
IntroRoundsServer._setDone = setDone
function IntroRoundsServer.unstick(player: Player, now: number): string?
	local profile = PlayerData.get(player) :: any
	if not profile or player:GetAttribute("CombatSession") ~= "Training" then
		stuckSince[player] = nil
		setDone[player] = nil
		return nil
	end
	local left = IntroRoundsServer.left(player)
	if left == 0 then
		-- (the set's done: HUNT BOUNTY or CONTINUE should have taken them out)
		if profile.IntroFinale ~= "Mines" and profile.IntroFinale ~= "Dungeon" and not setDone[player] then
			stuckSince[player] = nil
			return nil
		end
	elseif rivalUp(player) then
		stuckSince[player] = nil
		return nil
	end
	local since = stuckSince[player] or now
	stuckSince[player] = since
	local state = IntroRounds.state(profile)
	local choosing = IntroRoundsServer.huntNext(profile, state)
	local wait = if choosing
		then IntroRoundsServer.ChoiceWait
		elseif left == 0 then IntroRoundsServer.DoneOutAfter
		else IntroRoundsServer.StuckAfter
	if now - since < wait then
		return nil
	end
	stuckSince[player] = nil
	if left == 0 then
		setDone[player] = nil
		IntroRoundsServer._leave(player)
		return "Out"
	end
	player:SetAttribute("IntroRounds", nil)
	IntroRoundsServer._next(player)
	return "Next"
end

function IntroRoundsServer.watch()
	while true do
		task.wait(5)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local ok, problem = pcall(IntroRoundsServer.unstick, player, now)
			if not ok then
				warn("[IntroRounds] unstick: " .. tostring(problem))
			end
		end
		for player in stuckSince do
			if not player.Parent then
				stuckSince[player] = nil
			end
		end
	end
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
function IntroRoundsServer.dungeonPath(_player: Player): boolean
	-- (Off for everyone, the Owners too: the intro's six rounds, then the
	-- mines and the kaiju: IntroRoundsServer.finale.)
	return Config.Features ~= nil and Config.Features.IntroDungeon == true
end

-- How many rounds `player` has still to win (0 once their set's done),
-- on them as IntroRoundsLeft: no leaving the Arena till it's 0 (Server
-- ArenaSessions, the LEAVE button: Client Combat).
function IntroRoundsServer.left(player: Player): number
	local state = stateOf(player)
	if not state then
		return 0
	end
	return math.max(0, IntroRounds.Count - state.Won)
end
-- Whether they're held in the rounds now: rounds left, and they haven't
-- stepped out to the Outpost or the first boss (state.Paused: choose).
function IntroRoundsServer.held(player: Player): boolean
	local state = stateOf(player)
	return IntroRoundsServer.left(player) > 0 and not (state and state.Paused)
end
local function markLeft(player: Player)
	local left = IntroRoundsServer.left(player)
	player:SetAttribute("IntroRoundsLeft", if left > 0 and IntroRoundsServer.held(player) then left else nil)
end

-- After the six rounds, the intro's finale (Client IntroFinale): out by
-- the mines, a rock to hit, gems and enchanting in a few words, then the
-- rot minions coming, the kaiju roll, and the kaiju seeing them off.
-- profile.IntroFinale: "Mines" till it's done, then "Done"; the player's
-- IntroFinale attribute while it's to do.
IntroRoundsServer.Critters = {
	Count = 3, -- portals, a rot minion out of each
	Away = 24, -- studs ahead of them (inside the kaiju's reach, Kaiju.Follow.Engage)
	Hop = 1.6, -- seconds a portal crackles open before its minion hops out
	Stagger = 0.9, -- between one portal's hop and the next's
	Linger = 6, -- seconds a portal stays open after
	Land = 1.6, -- seconds after the hop it's held still (landed)
	Health = 0.5,
	Damage = 0.3,
	Life = 150,
}
local function markFinale(player: Player)
	local profile = PlayerData.get(player) :: any
	local stage = profile and profile.IntroFinale
	player:SetAttribute("IntroFinale", if stage == "Mines" or stage == "Dungeon" then stage else nil)
	-- (the lobby's intro doesn't ask about the first dungeon once it's done)
	player:SetAttribute("IntroDungeonCleared", if profile and profile.IntroDungeonCleared then true else nil)
end
-- The first dungeon owed (profile.IntroFinale "Dungeon": the HUNT BOUNTY
-- window, Client IntroFinale, holds them to it) cleared: a Rift boss beaten
-- (Server.RiftServer's recordWin). The lobby's intro is next ("Mines").
function IntroRoundsServer.owesDungeon(player: Player): boolean
	local profile = PlayerData.get(player) :: any
	return profile ~= nil and profile.IntroFinale == "Dungeon"
end
function IntroRoundsServer.dungeonCleared(player: Player)
	local profile = PlayerData.get(player) :: any
	if not profile or profile.IntroFinale ~= "Dungeon" then
		return false
	end
	profile.IntroFinale = "Mines"
	profile.IntroDungeonCleared = true
	markFinale(player)
	pcall(Analytics.event, player, "IntroDungeonCleared")
	pcall(function()
		require(script.Parent.Journey).reach(player, "Cleared the first dungeon")
		require(script.Parent.Funnel).reach(player, "Dungeon cleared")
	end)
	return true
end
local finaleCritters = {} :: { [Player]: { any } }
local finaleLoose = {} :: { [Player]: boolean } -- (the kaiju are out: the minions let go)
-- The steps the client says it's on (for the DEV spectator: IntroFinaleStep).
local FINALE_STEPS = { Mine = true, Gems = true, Minions = true, Kaiju = true, Invite = true, Over = true, Away = true }
-- In a fight (a 1v1, the Arena, a queue, the Rift): the lobby's intro waits,
-- never brings its minions in there.
local function busyElsewhere(player: Player): boolean
	return player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("DuelQueue") ~= nil
		or player:GetAttribute("RiftRun") ~= nil
end
IntroRoundsServer.busyElsewhere = busyElsewhere
-- The finale's minions gone (they went into a fight: they'll come again
-- when the lobby's intro does).
function IntroRoundsServer.clearCritters(player: Player)
	local list = finaleCritters[player]
	finaleCritters[player], finaleLoose[player] = nil, nil
	for _, enemy in list or {} do
		pcall(require(script.Parent.Enemies).remove, enemy)
	end
end
local function finale(player: Player, step: any, name: any)
	if step == "Step" then
		player:SetAttribute("IntroFinaleStep", if FINALE_STEPS[name] then name else nil)
		if FINALE_STEPS[name] and name ~= "Away" and name ~= "Over" then
			pcall(function()
				require(script.Parent.Journey).reach(player, "Lobby intro " .. string.lower(name))
			end)
		end
		return reply(true, "")
	end
	local profile = PlayerData.get(player) :: any
	if not profile or profile.IntroFinale ~= "Mines" then
		return reply(false, "Nothing to do here.")
	end
	if (step == "Critters" or step == "Fight") and busyElsewhere(player) then
		return reply(false, "Not in the middle of a fight.")
	end
	if step == "Critters" then
		-- Three rift portals tearing open ahead of them (FrontierServer's,
		-- drawn by RiftTear), a rot minion hopping out of each and landing,
		-- then held still (the cinematic shows them all come through) till
		-- the kaiju are out ("Fight").
		if finaleCritters[player] then
			return reply(true, "")
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return reply(false, "No character.")
		end
		local KaijuWilds = require(script.Parent.KaijuWilds)
		local Frontier = require(script.Parent.FrontierServer)
		local c = IntroRoundsServer.Critters
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
		local floorY = root.Position.Y - 3
		local list, portals = {}, {}
		finaleCritters[player] = list
		for i = 1, c.Count do
			-- (as in the sketch: left, middle a touch nearer, right a touch further)
			local angle = (i - (c.Count + 1) / 2) * 0.55
			local reach = c.Away + (if i == 2 then -6 elseif i == 3 then 4 else 0)
			local dir = (CFrame.Angles(0, angle, 0) * CFrame.new(look)).Position
			local at = Vector3.new(root.Position.X, floorY, root.Position.Z) + dir * reach
			local ok, anchor, life = pcall(Frontier.open, at, root.Position, {
				Prey = player,
				Hop = c.Hop + (i - 1) * c.Stagger,
				Linger = c.Linger,
			})
			if ok and anchor and life then
				table.insert(portals, { At = at, HopAt = life.HopAt })
				task.delay(math.max(0, life.HopAt - workspace:GetServerTimeNow()), function()
					if not player.Parent or finaleCritters[player] ~= list then
						return
					end
					local target = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local toward = if target then (target.Position - at) * Vector3.new(1, 0, 1) else -dir
					toward = if toward.Magnitude > 0.1 then toward.Unit else -dir
					local made, enemy = pcall(KaijuWilds.spawnBug, at, {
						Prey = player,
						Level = 1,
						Health = c.Health,
						Damage = c.Damage,
						Life = c.Life,
						Facing = if target then target.Position else at - dir,
						Hop = toward * 16 + Vector3.new(0, 24, 0),
						Title = "Rot Minion",
						-- (after them right here by the Shelter, and not off back
						-- through a rift while the kaiju roll plays)
						Hunt = true,
						Stay = true,
					})
					if made and enemy then
						table.insert(list, enemy)
						-- (landed: held there till the kaiju are out)
						task.delay(c.Land, function()
							local e = enemy :: any
							if not finaleLoose[player] and e.Root and e.Root.Parent then
								e.Root.Anchored = true
							end
						end)
					end
				end)
			end
		end
		return reply(true, "", { Portals = portals, Deployed = workspace:GetServerTimeNow() + c.Hop + (c.Count - 1) * c.Stagger + c.Land + 0.5 })
	elseif step == "Fight" then
		finaleLoose[player] = true
		for _, enemy in finaleCritters[player] or {} do
			local e = enemy :: any
			if e.Root and e.Root.Parent then
				e.Root.Anchored = false
			end
		end
		return reply(true, "")
	elseif step == "Left" then
		-- How many of them are still standing.
		local left = 0
		for _, enemy in finaleCritters[player] or {} do
			local e = enemy :: any
			if e.Alive and e.Model and e.Model.Parent then
				left += 1
			end
		end
		return reply(true, "", { Left = left })
	elseif step == "Invite" then
		-- Their answer to the first dungeon's window, for the funnel.
		local choice = if name == "Go" then "Go" else "Later"
		pcall(Analytics.event, player, "IntroDungeonInvite", choice)
		return reply(true, "")
	elseif step == "Done" then
		profile.IntroFinale = "Done"
		for _, enemy in finaleCritters[player] or {} do
			local e = enemy :: any
			if e.Root and e.Root.Parent then
				e.Root.Anchored = false
			end
		end
		finaleCritters[player] = nil
		finaleLoose[player] = nil
		markFinale(player)
		PlayerData.sync(player)
		-- (and a little after, the meteor: its Magma Golem, a first boss)
		local meteor = false
		pcall(function()
			meteor = require(script.Parent.MeteorGolemServer).soon(player)
		end)
		return reply(true, "Welcome to the Outpost, miner.", { Meteor = meteor })
	end
	return reply(false, "Unknown step.")
end
IntroRoundsServer.finale = finale

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

-- The set bonus into their gems (Shared.IntroRounds.SetGem's odds): the gem,
-- or nil if it couldn't be given.
function IntroRoundsServer.setGem(profile): any
	local GemGenerator = require(script.Parent.GemGenerator)
	local ok, gem = pcall(GemGenerator.generate, rng, "MiningStore", {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Rarity = IntroRounds.setGemTier(rng:NextNumber()),
	})
	if not ok or not gem or not Market.give(profile, { Kind = "Gem", Gem = gem }, math.huge, true) then
		warn("[IntroRounds] couldn't give the set bonus gem: " .. tostring(gem))
		return nil
	end
	profile.IntroSetGem = gem.Id
	return gem
end
-- What the card shows of it: its name, rarity, element, colour, and
-- whether the best build put it in a socket.
function IntroRoundsServer.setGemView(profile, gem)
	local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
	local socketed = false
	for key, held in (profile.Character or {}) do
		if type(key) == "string" and string.sub(key, -3) == "Gem" then
			if held == gem.Id or (type(held) == "table" and held.Id == gem.Id) then
				socketed = true
			end
		end
	end
	local shade = GemConfig.shade(gem)
	return {
		Name = GemConfig.displayName(gem),
		Tier = gem.Tier,
		Element = GemConfig.elementName(gem.Element),
		Color = shade and shade.Color or nil,
		Socketed = socketed,
	}
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
	markLeft(player)
	if state.Won >= IntroRounds.Count and (profile :: any).IntroFinale == nil then
		-- (the set's done: the first dungeon next, then the mines and the kaiju)
		(profile :: any).IntroFinale = "Dungeon"
		markFinale(player)
	end
	local event = { Phase = "Won", Round = round, Piece = piece, Where = where, More = more }
	-- (the dungeon path's last 1v1 won: next, the kaiju roll and the dungeon)
	if where ~= "Dungeon" and IntroRoundsServer.dungeonPath(player) and IntroRounds.stage(state, true) == "Dungeon" then
		event.Next = "Dungeon"
	end
	event.Reel, event.ReelLand = IntroRoundsServer.reel(slot, piece)
	IntroRoundsServer.warm(player) -- (built already by now, most times: a no-op)
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
	-- All six: the set bonus, a mystery gem, Rare or Ultra-Rare (once an
	-- account: IntroSetGem), before the best build so it can go in.
	local setGem = nil
	if state.Won >= IntroRounds.Count and not (profile :: any).IntroSetGem then
		setGem = IntroRoundsServer.setGem(profile)
	end
	-- Then their best build on, gems and all (no trip to the Inventory).
	local ok, pieces, gems = pcall(IntroRoundsServer.bestBuild, player, profile)
	if setGem then
		event.SetGem = IntroRoundsServer.setGemView(profile, setGem)
	end
	if ok and (pieces > 0 or gems > 0) then
		event.Auto = { Pieces = pieces, Gems = gems }
	elseif not ok then
		warn("[IntroRounds] auto equip failed: " .. tostring(pieces))
	end
	local done = state.Won >= IntroRounds.Count
	if done then
		setDone[player] = true
		PlayerData.addCoins(player, IntroRounds.SetCoins, "Tutorial")
		event.Coins = IntroRounds.SetCoins
	end
	Analytics.event(player, "IntroRound", round, slot, piece.Rarity, if done then "Done" else "Won")
	pcall(function()
		require(script.Parent.Journey).reach(player, if done then "Intro rounds all won" else string.format("Round %d won", round))
		if round == 1 then
			require(script.Parent.Funnel).reach(player, "Round 1 won")
		end
	end)
	event.View = IntroRounds.view(state)
	-- (the card's one way on: HUNT BOUNTY, while the first dungeon's owed)
	event.Hunt = IntroRoundsServer.huntNext(profile, state) or nil
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
	pcall(function()
		require(script.Parent.Journey).reach(player, string.format("Round %d lost", round))
	end)
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
	-- (CONTINUE ROUNDS on the card instead of HUNT BOUNTY: the journey's fork)
	if IntroRoundsServer.huntNext(PlayerData.get(player), state) then
		pcall(function()
			require(script.Parent.Journey).reach(player, string.format("Kept fighting after round %d", state.Won))
		end)
	end
	huntPending[player] = nil -- (CONTINUE ROUNDS after all)
	-- (back to the rounds after a step out: held in them again)
	if state.Paused then
		state.Paused = nil
		markLeft(player)
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
	IntroRoundsServer.warm(player)
	return reply(true, string.format("Round %d of %d!", round, IntroRounds.Count), { Round = round })
end

local function leaveRounds(player: Player)
	if IntroRoundsServer.held(player) then
		return reply(false, "Finish your intro rounds first.")
	end
	player:SetAttribute("IntroRounds", nil)
	player:SetAttribute("IntroRoundFight", nil)
	if player:GetAttribute("CombatSession") == "Training" then
		return require(script.Parent.ArenaSessions).leave(player)
	end
	return reply(true, "Back to the Outpost.")
end
-- HUNT BOUNTY's way out: off the Arena where they stand (never the lobby's
-- spawn first), then into the Outpost behind the loading screen, as the
-- Rift's gate only opens from there (RiftServer: problem). The client goes
-- on through the gate under the same cover (Client IntroRoundsUI.choose).
local function huntOut(player: Player)
	if IntroRoundsServer.held(player) then
		return reply(false, "Finish your intro rounds first.")
	end
	player:SetAttribute("IntroRounds", nil)
	player:SetAttribute("IntroRoundFight", nil)
	if player:GetAttribute("CombatSession") ~= nil then
		require(script.Parent.ArenaSessions).leave(player, true)
	end
	if player:GetAttribute("Outpost") ~= true then
		local ok, why = pcall(function()
			-- (no pod landing on the way through: it lands with them in it when
			-- they're home from the dungeon, Server.RiftServer)
			return require(script.Parent.OutpostServer)._enter(player, { NoPod = true })
		end)
		if not ok then
			warn("[IntroRounds] into the Outpost for HUNT BOUNTY: " .. tostring(why))
		end
	end
	return reply(true, "Into the Rift.")
end
-- The card after a win (from IntroRounds.ChoiceAfter wins on): out of the
-- rounds for now, to the Outpost ("Outpost": the mines, the gems, the
-- minions and the kaiju roll: IntroFinale) or to the first boss ("Boss":
-- the Bounty Board's Bombardiro Drago, then the mines when they're back).
-- The rest of the set waits: CONTINUE ROUNDS or PLAY takes it up again.
-- (The only way on is the first dungeon: HUNT BOUNTY. The lobby opens once
-- it's cleared: IntroRoundsServer.dungeonCleared.)
local CHOICES = { Boss = true }
-- Whether a win's card sends them to the first dungeon (HUNT BOUNTY): won a
-- round, rounds still to go, and the first dungeon not cleared yet (not
-- begun: IntroFinale nil, or owed: "Dungeon"). Once it's cleared ("Mines",
-- "Done") a win's card is the next round, as it always was.
function IntroRoundsServer.huntNext(profile: any, state: any): boolean
	if not profile or not state or profile.IntroDungeonCleared then
		return false
	end
	-- (the first ChoiceAfter rounds a must: then the dungeon's on offer)
	if state.Won < IntroRounds.ChoiceAfter then
		return false
	end
	return profile.IntroFinale == nil or profile.IntroFinale == "Dungeon"
end
-- HUNT BOUNTY picked on the card: the starter kaiju roll may play now (it
-- comes before the dungeon: KaijuServer.starterHeld), then choose.
function IntroRoundsServer.huntPending(player: Player): boolean
	return huntPending[player] == true
end
local function hunt(player: Player)
	local state, profile = stateOf(player)
	if not state or not IntroRoundsServer.huntNext(profile, state) then
		return reply(false, "The first dungeon isn't open to you yet.")
	end
	huntPending[player] = true
	return reply(true, "")
end
function IntroRoundsServer.choose(player: Player, which: any)
	local state, profile = stateOf(player)
	if not state or not CHOICES[which] then
		return reply(false, "Pick a way on.")
	end
	if state.Won < IntroRounds.ChoiceAfter then
		return reply(false, "Win all your intro rounds first.")
	end
	if not IntroRoundsServer.huntNext(profile, state) then
		-- (the first dungeon's behind them: out to the lobby, or their next
		-- round if any are left)
		if state.Won >= IntroRounds.Count then
			return leaveRounds(player)
		end
		return IntroRoundsServer._next(player)
	end
	state.Paused = true
	if (profile :: any).IntroFinale == nil then
		(profile :: any).IntroFinale = "Dungeon"
	end
	markFinale(player)
	markLeft(player)
	pcall(Analytics.event, player, "IntroChoice", state.Won, which)
	pcall(function()
		require(script.Parent.Journey).reach(player, "Chose HUNT BOUNTY")
		require(script.Parent.Funnel).reach(player, "Hunt bounty")
	end)
	local out = huntOut(player)
	out.Choice = which
	return out
end
IntroRoundsServer.choiceAfter = IntroRounds.ChoiceAfter

-- (the watch's ways on: IntroRoundsServer.unstick)
IntroRoundsServer._next, IntroRoundsServer._leave = nextRound, leaveRounds
IntroRoundsServer._hunt = hunt

local started = false
function IntroRoundsServer.start()
	if started then
		return
	end
	started = true
	-- (Duels and Duelist call in here on a win or a lost round.)
	require(script.Parent.Duels).IntroRounds = IntroRoundsServer
	-- (A new miner's reel pictures, built soon after they join: ready for
	-- their first fight's roll.)
	local function arrived(player: Player)
		-- (into a fight with the lobby's intro mid-way: its minions go)
		for _, key in { "MatchId", "CombatSession", "RiftRun" } do
			player:GetAttributeChangedSignal(key):Connect(function()
				if player:GetAttribute(key) ~= nil and finaleCritters[player] then
					IntroRoundsServer.clearCritters(player)
				end
			end)
		end
		task.delay(10, function()
			if player.Parent and IntroRoundsServer.eligible(player) then
				IntroRoundsServer.warm(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(arrived)
	for _, player in Players:GetPlayers() do
		arrived(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		warming[player] = nil
		huntPending[player] = nil
		setDone[player] = nil
	end)
	require(script.Parent.Duelist).IntroRounds = IntroRoundsServer
	Shop.register("IntroRoundNext", nextRound)
	Shop.register("IntroRoundLeave", leaveRounds)
	Shop.register("IntroRoundChoose", IntroRoundsServer.choose)
	Shop.register("IntroRoundHunt", hunt)
	Shop.register("IntroFinale", finale)
	-- Coming back mid-intro: straight back into their next round (they
	-- don't get the lobby till the six are won); the finale if it's to do.
	local function resume(player: Player)
		task.spawn(function()
			local waited = 0
			while player.Parent and waited < 90 and not (PlayerData.get(player) and player.Character) do
				task.wait(1)
				waited += 1
			end
			if not player.Parent then
				return
			end
			markLeft(player)
			markFinale(player)
			local profile = PlayerData.get(player) :: any
			if not profile or not (profile.Intro and profile.Intro.Done) then
				return -- (a first join: the intro's first fight starts the rounds)
			end
			task.wait(IntroRoundsServer.ResumeAfter)
			if player.Parent and IntroRoundsServer.held(player)
				and player:GetAttribute("CombatSession") == nil
				and player:GetAttribute("MatchId") == nil
				and player:GetAttribute("DuelQueue") == nil
			then
				nextRound(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(resume)
	for _, player in Players:GetPlayers() do
		resume(player)
	end
	task.spawn(IntroRoundsServer.watch)
	Players.PlayerRemoving:Connect(function(player)
		finaleCritters[player] = nil
		finaleLoose[player] = nil
	end)
	-- DEV > NEW INTRO: DUNGEON (Owners only): the new intro from its
	-- dungeon, on this account: its two 1v1s counted won (the pieces they
	-- paid kept), the dungeon's pieces still to come. Again any time.
	Shop.register("DevIntroDungeon", function(player: Player)
		local owners = Config.Playtest and Config.Playtest.Owners or {}
		if not table.find(owners, player.UserId) then
			return reply(false, "This test tool is for the game's owners.")
		end
		local profile = PlayerData.get(player)
		if not profile then
			return reply(false, "Your profile is still loading.")
		end
		local p = profile :: any
		local state = if type(p.IntroRounds) == "table" then p.IntroRounds else { Won = 0, Losses = 0, Pieces = {} }
		state.Won, state.Losses = IntroRounds.Duels, 0
		state.Pieces = if type(state.Pieces) == "table" then state.Pieces else {}
		p.IntroRounds = state
		player:SetAttribute("IntroRounds", nil)
		player:SetAttribute("IntroRoundFight", nil)
		PlayerData.sync(player)
		return reply(true, "New intro: into the dungeon.")
	end)
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
