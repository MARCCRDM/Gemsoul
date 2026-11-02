-- Finite cooperative dungeon runs. All membership, spawns and rewards are server-owned.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.DungeonRules)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local World = require(script.Parent.Parent.World.DungeonWorld)
local Party = require(script.Parent.Party)
local Raids = require(script.Parent.Raids)
local Duelist = require(script.Parent.Duelist)
local ArenaSessions = require(script.Parent.ArenaSessions)
local Analytics = require(script.Parent.Analytics)
local ArenaDrop = require(script.Parent.ArenaDrop)
local ArenaStreaks = require(script.Parent.ArenaStreaks)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local Restores = require(script.Parent.Restores)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local Shop = require(script.Parent.Shop)
local Feedback = require(script.Parent.Feedback)
local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
local Dungeon = {}
local function canTest(player)
	return Feedback.isOwner(player)
end
local runs, memberRun, slots = {}, {}, {}
local finish
local beginLoot
local function releaseReserve(p)
	local c = p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root and p:GetAttribute("DungeonSelecting") then root.Anchored = false end
	local shield = c and c:FindFirstChild("MinerReserveShield")
	if shield then shield:Destroy() end
	p:SetAttribute("DungeonSelecting", nil)
	p:SetAttribute("DungeonAvailableMiners", nil)
	p:SetAttribute("DungeonSelectEnds", nil)
end
local function reservesPending(run)
	for p in run.Selecting do
		if p.Parent and memberRun[p] == run then return true end
	end
	return false
end
local function living(run)
	local result = {}
	for _, p in run.Members do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if
			p.Parent
			and memberRun[p] == run
			and not p:GetAttribute("DungeonSelecting")
			and p:GetAttribute("DungeonId") == run.Id
			and p:GetAttribute("CombatSession") == "Raid"
			and h
			and h.Health > 0
		then
			table.insert(result, p)
		end
	end
	return result
end
local function announce(run, text)
	for _, p in run.Members do
		if p.Parent and memberRun[p] == run then
			p:SetAttribute("DungeonObjective", text)
			-- (The first dungeon's tracker shows it: Client FirstDungeonUI.)
			if not run.First then
				Remotes.Notify:FireClient(p, text)
			end
		end
	end
end
-- What a room's state is, on its members (the first dungeon's tracker):
-- DungeonPhase "Fight" | "Move" | "Loot", DungeonFoesLeft / DungeonFoesTotal.
local function phase(run, name, left, total)
	for _, p in run.Members do
		if p.Parent and memberRun[p] == run then
			p:SetAttribute("DungeonPhase", name)
			p:SetAttribute("DungeonFoesLeft", left)
			if total then
				p:SetAttribute("DungeonFoesTotal", total)
			end
		end
	end
end
-- Intro rounds still to win (the first dungeon's way back to them).
local function roundsLeft(p): number
	local state = IntroRounds.state(PlayerData.get(p))
	return if state then math.max(0, IntroRounds.Count - state.Won) else 0
end
-- Something broke: in the server's output, and on an owner's screen too
-- (an owner's test says what went wrong, not just that it did).
local function report(run, what, problem)
	warn("[Dungeon] " .. what .. ": " .. tostring(problem))
	for _, p in run.Members do
		if p.Parent and canTest(p) then
			Remotes.Notify:FireClient(p, "[Dungeon] " .. what .. ": " .. string.sub(tostring(problem), 1, 160))
		end
	end
end
finish = function(run, won, reason)
	if run.Done then
		return
	end
	run.Done = true
	runs[run.Id] = nil
	Duelist.removeDungeon(run.Id)
	-- A dungeon's boss stands at its squad's level (their average): a clear's
	-- XP goes by that against yours (Shared.Levelling).
	local sum, count = 0, 0
	for _, p in run.Members do
		if p.Parent then
			sum += Progress.levelOf(p)
			count += 1
		end
	end
	local squadLevel = if count > 0 then sum / count else nil
	-- Clear membership before invoking Arena leave, to make cleanup reentrant.
	for _, p in run.Members do
		if memberRun[p] == run then
			local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local eligible = won
				and (not run.Test or run.First)
				and p.Parent
				and p:GetAttribute("DungeonId") == run.Id
				and humanoid
				and humanoid.Health > 0
			memberRun[p] = nil
			if p.Parent then
				releaseReserve(p)
				p:SetAttribute("DungeonId", nil)
				p:SetAttribute("DungeonTest", nil)
				p:SetAttribute("DungeonObjective", nil)
				p:SetAttribute("DungeonRoom", nil)
				p:SetAttribute("DungeonRooms", nil)
				p:SetAttribute("DungeonBoss", nil)
				p:SetAttribute("DungeonKaiju", nil)
				p:SetAttribute("DungeonPhase", nil)
				p:SetAttribute("DungeonFoesLeft", nil)
				p:SetAttribute("DungeonFoesTotal", nil)
				p:SetAttribute("SparDown", nil)
				local shield = p.Character and p.Character:FindFirstChild("FirstDownShield")
				if shield then
					shield:Destroy()
				end
				local downRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if downRoot and run.First then
					downRoot.Anchored = false
				end
				-- A clear also restores a share of the pick's swings (Shared.SwingRestore).
				local swings, xp = 0, 0
				if eligible then
                    PlayerData.training(p, "DungeonComplete")
					PlayerData.addCoins(p, 300, "Dungeon")
					xp = Progress.won(p, "DungeonBoss", squadLevel, "SlayBrute")
					swings = Restores.give(p, SwingRestore.Dungeon)
				end
				ArenaSessions.leave(p)
				Remotes.Notify:FireClient(
					p,
					reason
						.. (if eligible then string.format(" +300 coins, +%d XP.", xp) else "")
						.. (if swings > 0 then string.format(" +%d swings!", swings) else "")
				)
			end
		end
	end
	run.World.Folder:Destroy()
	slots[run.Slot] = nil
end
-- A boss's gem (free in each one's boss cache): of its element,
-- Ultra Rare at gear tier 4, Legendary at 5, its surge at tier 4, rank III.
-- (The Rift's boss pays the same: Server.RiftServer.)
function Dungeon.bossGem(element: string, tier: number?)
	local rng = Random.new()
	local rarity = if tier == 5 then "Legendary" else "UltraRare"
	local band = GemRoller.ByRarity[rarity]
	local gem = {
		Source = "PvEDrop",
		Found = os.time(),
		CutMethod = "Natural",
		Id = PlayerData.newGemId(),
		Element = element,
		Tier = rarity,
		SurgeTier = 4,
		SurgeRank = 3,
		Size = rng:NextInteger(band.Metrics[1], band.Metrics[2]),
		Clarity = rng:NextInteger(band.Metrics[1], band.Metrics[2]),
		Cut = rng:NextInteger(band.Metrics[1], band.Metrics[2]),
	}
	gem.Surge = (if rng:NextNumber() < 0.5 then GemRoller.SurgeVariants else GemRoller.Surges)[gem.Element][4]
	return gem
end
-- The boss down: everyone still standing gets a boss cache of their own
-- (Systems/ArenaStreaks.bossCache, Shared.BossLoot): its gem and six pieces
-- of gear to keep three of, to open any time. The run ends a few seconds on.
beginLoot = function(run, room)
	if run.Loot or run.Done then
		return
	end
	Duelist.removeDungeon(run.Id) -- clear hostile actors
	if run.Test and not run.First then
		finish(run, true, "Owner expedition complete. No rewards.")
		return
	end
	local boss = Rules.specOf(room)
	run.Loot = { Boss = boss }
	for _, p in living(run) do
		ArenaStreaks.bossCache(p, boss, Dungeon.bossGem(boss.Element, room.GearTier), "Dungeon")
	end
	if run.First then
		-- The victory card (Client FirstDungeonUI): how it went, the boss
		-- cache, then on (CONTINUE, or by itself after WinSeconds).
		phase(run, "Loot", 0)
		announce(run, "THE BEACHHEAD IS TAKEN · Open your boss cache.")
		local first = Rules.First
		for _, p in living(run) do
			Remotes.Social:FireClient(p, "FirstDungeon", {
				Phase = "Won",
				Boss = boss.Name,
				Seconds = first.WinSeconds,
				Time = math.floor(os.clock() - run.Started),
				Downs = run.Downs[p] or 0,
				Coins = 300,
				RoundsLeft = roundsLeft(p),
			})
		end
		task.delay(first.WinSeconds, function()
			finish(run, true, "That's one. There are more out there. Back to the Outpost: gear up.")
		end)
		return
	end
	announce(run, "BOSS DEFEATED · Each of you gets a boss cache: open it to roll your loot.")
	task.delay(5, function()
		finish(run, true, "Colossus defeated. Expedition complete.")
	end)
end
local function spawnRoom(run, index)
	if run.Done then
		return
	end
	local members = living(run)
	local room = run.Rooms[index]
	if room.Boss and #members < (if run.Test then 1 else Rules.Min) then
		finish(run, false, "Boss entry requires three surviving squad members. Regroup and queue again.")
		return
	end
	run.Index = index
	run.Remaining = #room.Foes
	run.Cleared = false
	if run.Beacon then
		run.Beacon:Destroy()
		run.Beacon = nil
	end
	local spec = Rules.specOf(room)
	for _, p in members do
		p:SetAttribute("DungeonRoom", index)
		p:SetAttribute("DungeonBoss", if room.Boss then spec.Name else nil)
	end
	announce(
		run,
		if run.First
			then (if room.Boss
				then string.format("THE NEST · %s · weak to %s", spec.Name, GemConfig.elementName(spec.Weakness))
				else string.format("%s · defeat %d fighter%s", room.Name or ("Room " .. index), #room.Foes, if #room.Foes == 1 then "" else "s"))
		elseif room.Boss
			then "BOSS: Colossus "
				.. spec.Name
				.. " · "
				.. GemConfig.elementName(spec.Element)
				.. " · weak to "
				.. GemConfig.elementName(spec.Weakness)
			else string.format(
				"Room %d/%d · %s enemies · gear tier %d/5 · defeat %d fighters",
				index,
				#run.Rooms,
				GemConfig.elementName(spec.Element),
				room.GearTier or 1,
				#room.Foes
			)
	)
	local arrivals = {}
	phase(run, "Fight", #room.Foes, #room.Foes)
	-- A foe of this room down (`kind`: its spec's; `bossKill`: the room's boss itself).
	local function deathOf(kind, bossKill)
		return function()
				if run.Done or (not run.OpenWorld and run.Index ~= index) then
					return
				end
                if bossKill and (not run.Test or run.First) then
                    local spec = Rules.specOf(room, kind)
                    local here = living(run)
                    for _, member in here do
                        PlayerData.training(member, "Boss")
                        Analytics.event(member, "BossDefeated", #here, spec and spec.Id or "Boss", "Dungeon")
                    end
                end
				if run.OpenWorld then
					if room.Boss then
						beginLoot(run, room)
					end
					return
				end
				run.Remaining -= 1
				if run.Remaining > 0 then
					phase(run, "Fight", run.Remaining)
					if not run.First then
						announce(run, string.format("Room %d · %d fighters remaining", index, run.Remaining))
					end
					return
				end
				run.Cleared = true
				if room.Boss then
					beginLoot(run, room)
					return
				end
				local gate = run.World.Gates[index]
				if gate then
					gate:Destroy()
				end
				-- A checkpoint restores survivors; fallen players are not silently revived.
				for _, p in living(run) do
					local h = p.Character:FindFirstChildOfClass("Humanoid")
					h.Health = h.MaxHealth
					CombatServer.reset(p)
				end
				phase(run, "Move", 0)
				if run.First then
					-- (a beam over the next room: where to go)
					local nextCenter = run.World.Centers[index + 1]
					if nextCenter and World.beacon then
						local ok, beam = pcall(World.beacon, run.World.Folder, nextCenter, index + 1 == #run.Rooms)
						if ok then
							run.Beacon = beam
						else
							report(run, "beacon", beam)
						end
					end
				end
				announce(
					run,
					if run.First
						then string.format("%s clear · Through the gate: on to %s.", room.Name or ("Room " .. index), (run.Rooms[index + 1] or {}).Name or "the next room")
						else string.format("Room %d cleared. Gate open — proceed to room %d.", index, index + 1)
				)
		end
	end
	for n, kind in room.Foes do
		local center = run.World.Centers[index]
		local angle = (n - 1) / #room.Foes * math.pi * 2
		local enemy = Duelist.spawnDungeon(members, run.Id, {
			Room = index,
			GearTier = room.GearTier or (if room.Boss then 4 else 1),
			Center = center,
			OpenWorld = run.OpenWorld,
			Bandit = room.Bandit,
			MinPlayers = if run.Test then 1 else Rules.Min,
			Spot = center + Vector3.new(math.cos(angle) * 14, if room.Boss then 7 else 4, math.sin(angle) * 14),
			Spec = Rules.specOf(room, kind),
			Boss = room.Boss,
			HealthScale = room.HealthScale,
			DamageScale = if run.First then (room.DamageScale or 1) * (run.PieceScale or 1) else nil,
			KaijuFoes = run.First == true,
			OnDeath = deathOf(kind, room.Boss),
		})
		if not enemy then
			finish(run, false, "The encounter could not start. Your squad has been returned safely.")
			return
		end
		table.insert(arrivals, enemy.Model)
		-- The first dungeon's boss: at half health it's enraged, and its
		-- rot-spawn join the fight (Rules.First.Enrage).
		if run.First and room.Boss and enemy.Humanoid and enemy.Humanoid.HealthChanged then
			local enrage = Rules.First.Enrage
			local connection
			connection = enemy.Humanoid.HealthChanged:Connect(function(health)
				local most = enemy.Humanoid.MaxHealth
				if run.Enraged or run.Done or run.Index ~= index or most <= 0 or health <= 0 or health > most * enrage.At then
					return
				end
				run.Enraged = true
				if connection then
					connection:Disconnect()
				end
				local spec = Rules.specOf(room, kind)
				announce(run, string.format("%s IS ENRAGED · Its rot-spawn join the fight!", string.upper(spec.Name)))
				for a, id in enrage.Adds do
					local addSpec = Rules.Roster[Rules.rosterIndex(id)]
					local angle2 = a / #enrage.Adds * math.pi * 2 + 0.6
					local add = Duelist.spawnDungeon(living(run), run.Id, {
						Room = index,
						GearTier = 1,
						Center = center,
						MinPlayers = 1,
						Spot = center + Vector3.new(math.cos(angle2) * 18, 4, math.sin(angle2) * 18),
						Spec = addSpec,
						Boss = false,
						HealthScale = enrage.AddHealth,
						DamageScale = enrage.AddDamage * (run.PieceScale or 1),
						KaijuFoes = true,
						OnDeath = deathOf(nil, false),
					})
					if add then
						run.Remaining += 1
					end
				end
				phase(run, "Fight", run.Remaining)
			end)
		end
	end
	if not run.Inserted and not run.OpenWorld then
		ArenaDrop.encounter(members, arrivals, true, false, true)
		run.Inserted = true
	end
end
local function safeSpawnRoom(run, index)
	local ok, problem = pcall(spawnRoom, run, index)
	if not ok then
		report(run, "encounter failed", problem)
		finish(run, false, "The encounter failed to load. Please queue again.")
	end
end
local function queue(player, testMode)
	-- The campaign's first dungeon (Rules.First): solo, for anyone while it's
	-- on (Config.Features.FirstDungeon); off, for no one (owners too).
	local first = testMode == "First"
	local testing = testMode ~= nil and not first and canTest(player)
	if testMode ~= nil and not first and not testing then
		return Shop.reply(false, "Dungeon testing is restricted to playtest owners.")
	end
	if first and not (Config.Features and Config.Features.FirstDungeon == true) then
		return Shop.reply(false, "The Rot Beachhead is off for now.")
	end
	-- Switched off (Config.Features): only the owners' tests get in.
	if not testing and not first and Config.Features and Config.Features.Dungeons == false then
		return Shop.reply(false, "Squad dungeons are closed for the beta.")
	end
	local party = Party.of(player)
	local solo = testing or first
	local members = if solo then { player } else party and party.Members or {}
	local allReady = party ~= nil
	for _, p in members do
		if not party or not party.Ready[p] then
			allReady = false
		end
	end
	local ok, why = Rules.canEnter(#members, party ~= nil and party.Leader == player, allReady)
	if not ok and not solo then
		return Shop.reply(false, why)
	end
	for _, p in members do
		if memberRun[p] then
			return Shop.reply(false, "A member is already in a dungeon.")
		end
		local busy = Raids.busy(p)
		if busy then
			return Shop.reply(false, busy)
		end
	end
	local slot
	for i = 1, 8 do
		if not slots[i] then
			slot = i
			break
		end
	end
	if not slot then
		return Shop.reply(false, "All dungeon instances are busy. Try again shortly.")
	end
	local id = "D" .. HttpService:GenerateGUID(false)
	local run = {
		Id = id,
		Members = table.clone(members),
		PartyId = party and party.Id,
		Test = solo, -- (solo: no squad minimum)
		OpenWorld = testing and testMode == "OpenWorld",
		-- The campaign's first dungeon, the Rot Beachhead (Rules.First): solo,
		-- with the player's kaiju, a knock-down card instead of a reserve.
		First = first,
		Down = {},
		Downs = {}, -- (each player's knock-downs: the victory card's)
		Slot = slot,
		Index = 1,
		Started = os.clock(),
		Defeated = {},
		Selecting = {},
		Done = false,
	}
	slots[slot] = true
	runs[id] = run
	-- Lock the roster synchronously before any work that could yield.
	for _, p in run.Members do
		memberRun[p] = run
		run.Defeated[p] = {}
		p:SetAttribute("DungeonId", id)
		p:SetAttribute("DungeonTest", testing or nil)
		p:SetAttribute("RaidId", id)
		p:SetAttribute("PvPEnabled", false)
		p:SetAttribute("CombatSession", "Raid")
		if run.First then
			p:SetAttribute("DungeonKaiju", true)
		end
	end
	local success, problem = pcall(function()
		for _, p in run.Members do
			ArenaDrop.prepare(p)
		end
		run.Rooms = if run.OpenWorld then Rules.generateOpen(Random.new()) else Rules.generate(Random.new())
		if testing and testMode == "Sahur" then
			-- (Straight to the boss: the three-headed Tung Tung Tung Sahur.)
			local sahur = 1
			for i, spec in Rules.Bosses do
				if spec.Id == "SahurTrio" then
					sahur = i
				end
			end
			run.Rooms = { { Index = 1, X = 0, Z = 0, Boss = true, Theme = sahur, Foes = { sahur }, Pillars = 2 } }
		end
		if run.First then
			run.Rooms = Rules.firstRooms()
			-- (Softer hits the fewer intro pieces they've won; an older save, geared, as six.)
			local state = IntroRounds.state(PlayerData.get(player))
			run.PieceScale = Rules.firstDamage(if state then state.Won else 6)
		end
		for _, p in run.Members do
			p:SetAttribute("DungeonRooms", #run.Rooms)
		end
		run.World = (if run.OpenWorld then World.buildOpen else World.build)(
			id,
			run.Rooms,
			Vector3.new(2500 + slot * 1400, 0, 2500),
			if run.First then "Rot" else nil
		)
		if run.First then
			local dressed, problem = pcall(World.dressBeachhead, run.World.Folder, run.World.Centers)
			if not dressed then
				report(run, "beachhead dressing", problem)
			end
		end
		for i, p in run.Members do
			CombatServer.reset(p)
			local spot = (run.World.Arrival or run.World.Centers[1])
				+ Vector3.new((i - (#run.Members + 1) / 2) * 7, 4, if run.OpenWorld then 0 else -22)
			local target = run.World.Origin or run.World.Centers[1]
			p.Character:PivotTo(CFrame.lookAt(spot, Vector3.new(target.X, spot.Y, target.Z)))
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			h.Health = h.MaxHealth
		end
		announce(
			run,
			if run.First
				then "THE ROT BEACHHEAD · Scout the base, then take it. Your kaiju fight with you."
			elseif testing
				then "OWNER TEST  -  solo enabled, no rewards. Orbital deployment inbound."
				else "PATHWAY DUNGEON · Clear five linked canyon encounters. Follow the trail to the Colossus."
		)
		task.delay(0.1, function()
			if run.Done then
				return
			end
			if #living(run) < (if run.Test then 1 else Rules.Min) then
				finish(run, false, "Three players are required to begin. Queue cancelled.")
				return
			end
			if run.OpenWorld then
				for index = 1, #run.Rooms do
					if run.Done then
						break
					end
					safeSpawnRoom(run, index)
				end
				if not run.Done then
					-- Populate the world before the squad descends; NPCs never use pods.
					ArenaDrop.encounter(living(run), {}, true)
					run.Inserted = true
					announce(
						run,
						"OPEN EXPEDITION · Explore camps and ore fields. Defeat the central Colossus. Bandits are neutral until attacked."
					)
				end
			else
				safeSpawnRoom(run, 1)
			end
		end)
	end)
	if not success then
		report(run, "start failed", problem)
		if not run.World then
			run.World = { Folder = workspace:FindFirstChild("Dungeon_" .. id) or Instance.new("Folder") }
		end
		finish(run, false, "Dungeon setup failed. Please try again.")
		return Shop.reply(false, "Dungeon setup failed.")
	end
	if run.First then
		for _, p in run.Members do
			Remotes.Social:FireClient(p, "FirstDungeon", { Phase = "In", RoundsLeft = roundsLeft(p) })
		end
	end
	return Shop.reply(true, "Dungeon queued for your ready squad. Deploying now.")
end
local function chooseReserve(p, index)
	local run = memberRun[p]
	local pending = run and run.Selecting[p]
	local profile = PlayerData.get(p)
	if not run or run.Done or not pending or pending.Deploying or not profile then
		return Shop.reply(false, "No replacement deployment is available.")
	end
	if not MinerRoster.valid(index) or run.Defeated[p][index] or not profile.Miners.Slots[index] then
		return Shop.reply(false, "That miner is already defeated in this run.")
	end
	pending.Deploying = true
	if not PlayerData.selectMiner(p, index) then
		pending.Deploying = false
		return Shop.reply(false, "That miner could not be selected.")
	end
	task.spawn(function()
		local ok, problem = pcall(function()
			local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then p:LoadCharacterAsync() end
			task.wait(0.2) -- allow the new equipment's stats to reach the avatar
			if run.Done or memberRun[p] ~= run or not p.Parent then return end
			local c = p.Character
			local humanoid = c and c:FindFirstChildOfClass("Humanoid")
			assert(humanoid and humanoid.Health > 0, "Replacement avatar did not load")
			releaseReserve(p)
			ArenaDrop.prepare(p)
			local center = run.World.Centers[run.Index] or run.World.Arrival
			local position = center + Vector3.new(0, 4, -22)
			c:PivotTo(CFrame.lookAt(position, center + Vector3.new(0, 4, 0)))
			p:SetAttribute("RaidId", run.Id)
			p:SetAttribute("CombatSession", "Raid")
			CombatServer.reset(p)
			humanoid.Health = humanoid.MaxHealth
			run.Selecting[p] = nil
			ArenaDrop.encounter({ p }, {}, true)
		end)
		if not ok then
			warn("[Dungeon] reserve deployment failed: " .. tostring(problem))
			if memberRun[p] == run then ArenaSessions.leave(p) end
		end
	end)
	return Shop.reply(true, "Deploying Miner " .. index .. ".")
end
-- The first dungeon's knock-down: down where they fell (shielded, the
-- Outpost's knock-down on screen), then a card: RECOVER at the start of this
-- room (its fighters back to full), or back to the intro fights while there
-- are rounds left to win (Client FirstDungeonUI). RECOVER by itself after
-- ChooseSeconds.
local function firstDown(run, p, humanoid)
	if run.Down[p] then
		return true
	end
	if humanoid.Health <= 0 then
		return false
	end
	local first = Rules.First
	run.Down[p] = { Until = os.clock() + first.DownSeconds + first.ChooseSeconds }
	run.Downs[p] = (run.Downs[p] or 0) + 1
	humanoid.Health = math.max(1, math.min(humanoid.Health, 1))
	CombatServer.reset(p)
	local shield = Instance.new("ForceField")
	shield.Name, shield.Visible, shield.Parent = "FirstDownShield", false, p.Character
	p:SetAttribute("SparDown", workspace:GetServerTimeNow() + first.DownSeconds)
	Remotes.CombatFx:FireAllClients("SparKO", p.UserId, 0)
	task.delay(first.DownSeconds, function()
		if run.Done or memberRun[p] ~= run or not run.Down[p] then
			return
		end
		p:SetAttribute("SparDown", nil)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
		end
		local room = run.Rooms[run.Index]
		Remotes.Social:FireClient(p, "FirstDungeon", {
			Phase = "Down",
			Room = room and room.Name,
			Boss = room and room.Boss and Rules.specOf(room).Name or nil,
			RoundsLeft = roundsLeft(p),
			Seconds = first.ChooseSeconds,
		})
	end)
	return true
end
-- RECOVER: up at the start of the room they fell in, full health, its fighters too.
local function firstRecover(p)
	local run = memberRun[p]
	if not run or not run.First or not run.Down[p] then
		return Shop.reply(false, "You're not down.")
	end
	run.Down[p] = nil
	local c = p.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		finish(run, false, "Knocked out. The Rot Beachhead waits for you.")
		return Shop.reply(false, "Knocked out.")
	end
	local shield = c:FindFirstChild("FirstDownShield")
	if shield then
		shield:Destroy()
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
	p:SetAttribute("SparDown", nil)
	local center = run.World.Centers[run.Index] or run.World.Centers[1]
	local spot = center + Vector3.new(0, 4, -22)
	c:PivotTo(CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z)))
	humanoid.Health = humanoid.MaxHealth
	CombatServer.reset(p)
	Duelist.healDungeon(run.Id)
	announce(run, "Back on your feet. Watch the wind-ups this time.")
	return Shop.reply(true, "")
end
-- Out of the first dungeon, any time (no rewards): "Intro", back to the
-- intro fights (the client starts the next round), or "Lobby".
local function firstQuit(p, where)
	local run = memberRun[p]
	if not run or not run.First then
		return Shop.reply(false, "You're not in the Rot Beachhead.")
	end
	local lobby = where == "Lobby" or roundsLeft(p) == 0
	run.Down[p] = nil
	finish(
		run,
		false,
		if lobby
			then "Back to the lobby. The Rot Beachhead waits for you."
			else "Back to the intro fights: win more gear, then the Rot Beachhead waits."
	)
	return Shop.reply(true, "", { To = if lobby then "Lobby" else "Intro" })
end
-- CONTINUE on the victory card: out now, with the clear's rewards.
local function firstDone(p)
	local run = memberRun[p]
	if not run or not run.First or not run.Loot then
		return Shop.reply(false, "The Rot Beachhead isn't taken yet.")
	end
	finish(run, true, "That's one. There are more out there. Back to the Outpost: gear up.")
	return Shop.reply(true, "", { To = if roundsLeft(p) > 0 then "Intro" else "Lobby" })
end
local function reserveAfterDefeat(p, humanoid)
	local run = memberRun[p]
	if run and run.First then
		return firstDown(run, p, humanoid)
	end
	local profile = PlayerData.get(p)
	if not run or run.Done or not profile or not profile.Miners then return false end
	if run.Selecting[p] then return true end
	run.Defeated[p][profile.Miners.Active] = true
	local available = MinerRoster.remaining(profile.Miners, run.Defeated[p])
	if #available == 0 then return false end
	run.Selecting[p] = { Ends = os.clock() + 30 }
	p:SetAttribute("DungeonSelecting", true)
	p:SetAttribute("DungeonAvailableMiners", table.concat(available, ","))
	p:SetAttribute("DungeonSelectEnds", workspace:GetServerTimeNow() + 30)
	if humanoid.Health > 0 then humanoid.Health = 1 end
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end
	local shield = Instance.new("ForceField")
	shield.Name, shield.Visible, shield.Parent = "MinerReserveShield", false, p.Character
	CombatServer.reset(p)
	return true
end
function Dungeon.queueParty(player)
	return queue(player)
end
function Dungeon.start()
	Shop.register("DungeonMinerSelect", chooseReserve)
	Shop.register("FirstDungeonRecover", firstRecover)
	Shop.register("FirstDungeonQuit", firstQuit)
	Shop.register("FirstDungeonDone", firstDone)
	CombatServer.onDungeonLethal(reserveAfterDefeat)
	Shop.register("PartyDungeon", function(player)
		return queue(player)
	end)
	-- The Rot Beachhead from the intro rounds' card or the DEV panel (Client FirstDungeonUI).
	Shop.register("FirstDungeon", function(player)
		return queue(player, "First")
	end)
	Shop.register("DungeonTest", function(player, mode)
		if not canTest(player) then
			return Shop.reply(false, "Dungeon testing is restricted to playtest owners.")
		end
		if mode ~= "Sahur" and mode ~= "Full" and mode ~= "OpenWorld" and mode ~= "First" then
			return Shop.reply(false, "Choose Pathway, Open World, Sahur, or First.")
		end
		return queue(player, mode)
	end)
	ArenaSessions.onDungeonLeave = function(p)
		local run = memberRun[p]
		if not run then
			return
		end
		memberRun[p] = nil
		run.Selecting[p] = nil
		releaseReserve(p)
		p:SetAttribute("DungeonId", nil)
		p:SetAttribute("DungeonTest", nil)
		p:SetAttribute("DungeonRoom", nil)
		p:SetAttribute("DungeonRooms", nil)
		p:SetAttribute("DungeonBoss", nil)
		p:SetAttribute("DungeonObjective", nil)
		p:SetAttribute("DungeonKaiju", nil)
		p:SetAttribute("DungeonPhase", nil)
		p:SetAttribute("DungeonFoesLeft", nil)
		p:SetAttribute("DungeonFoesTotal", nil)
		p:SetAttribute("SparDown", nil)
		if run.Down then
			run.Down[p] = nil
		end
		local shield = p.Character and p.Character:FindFirstChild("FirstDownShield")
		if shield then
			shield:Destroy()
		end
		local downRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if downRoot and run.First then
			downRoot.Anchored = false
		end
		if #living(run) == 0 and not reservesPending(run) then
			finish(run, false, "The squad has left the dungeon.")
		end
	end
	local function watch(p)
		p:SetAttribute("CanTestDungeon", canTest(p))
		p.CharacterRemoving:Connect(function()
			if memberRun[p] and not p:GetAttribute("DungeonSelecting") then
				ArenaSessions.leave(p)
			end
		end)
		local function watchDeath(c)
			local h = c:WaitForChild("Humanoid", 10)
			if p:GetAttribute("DungeonSelecting") then
				local root = c:WaitForChild("HumanoidRootPart", 10)
				if root and p:GetAttribute("DungeonSelecting") then root.Anchored = true end
			end
			if h then h.Died:Connect(function() reserveAfterDefeat(p, h) end) end
		end
		p.CharacterAdded:Connect(watchDeath)
		if p.Character then task.spawn(watchDeath, p.Character) end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		if memberRun[p] then
			ArenaSessions.onDungeonLeave(p)
		end
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 0.5 then
			return
		end
		timer = 0
		for _, run in runs do
			if run.Done or not run.World then
				continue
			end
			local alive = living(run)
			for p, pending in run.Selecting do
				if not pending.Deploying and os.clock() >= pending.Ends then
					local profile = PlayerData.get(p)
					local available = MinerRoster.remaining(profile and profile.Miners, run.Defeated[p])
					if available[1] then chooseReserve(p, available[1]) end
				end
			end
			if run.First then
				for p, down in run.Down do
					if os.clock() >= down.Until then
						firstRecover(p)
					end
				end
			end
			if #alive == 0 and not reservesPending(run) then
				finish(run, false, "Squad defeated. Regroup and try again.")
				continue
			end
			if not run.Loot and os.clock() - run.Started > Rules.TimeLimit then
				finish(run, false, "Dungeon time limit reached.")
				continue
			end
			for _, p in alive do
				local party = Party.of(p)
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local close = false
				if root and run.OpenWorld then
					local offset = root.Position - run.World.Origin
					close = math.abs(offset.X) < Rules.OpenRadius
						and math.abs(offset.Z) < Rules.OpenRadius
						and math.abs(offset.Y) < 80
				end
				if root and not run.OpenWorld then
					for _, center in run.World.Centers do
						local offset = root.Position - center
						if math.abs(offset.X) < 62 and math.abs(offset.Z) < 62 and math.abs(offset.Y) < 40 then
							close = true
							break
						end
					end
				end
				if (not run.Test and (not party or party.Id ~= run.PartyId)) or not close then
					ArenaSessions.leave(p)
				end
			end
			if not run.OpenWorld and run.Cleared and not run.Done and not reservesPending(run) and run.Index < #run.Rooms then
				local center = run.World.Centers[run.Index + 1]
				for _, p in living(run) do
					local root = p.Character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - center).Magnitude < 28 then
						safeSpawnRoom(run, run.Index + 1)
						break
					end
				end
			end
		end
	end)
end
return Dungeon
