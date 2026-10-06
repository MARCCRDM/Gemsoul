-- Finite cooperative dungeon runs. All membership, spawns and rewards are server-owned.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.DungeonRules)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local World = require(script.Parent.Parent.World.DungeonWorld)
local Party = require(script.Parent.Party)
local Raids = require(script.Parent.Raids)
local Duelist = require(script.Parent.Duelist)
local ArenaSessions = require(script.Parent.ArenaSessions)
local ArenaDrop = require(script.Parent.ArenaDrop)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)
local Feedback = require(script.Parent.Feedback)
local Dungeon = {}
local function canTest(player)
	return Feedback.isOwner(player) or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end
local runs, memberRun, slots = {}, {}, {}
local finish
local beginLoot
local function living(run)
	local result = {}
	for _, p in run.Members do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if
			p.Parent
			and memberRun[p] == run
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
			Remotes.Notify:FireClient(p, text)
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
	-- Clear membership before invoking Arena leave, to make cleanup reentrant.
	for _, p in run.Members do
		if memberRun[p] == run then
			local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local eligible = won
				and not run.Test
				and p.Parent
				and p:GetAttribute("DungeonId") == run.Id
				and humanoid
				and humanoid.Health > 0
			memberRun[p] = nil
			if p.Parent then
				p:SetAttribute("DungeonId", nil)
				p:SetAttribute("DungeonTest", nil)
				p:SetAttribute("DungeonObjective", nil)
				p:SetAttribute("DungeonRoom", nil)
				p:SetAttribute("DungeonBoss", nil)
				p:SetAttribute("DungeonLoot", nil)
				p:SetAttribute("DungeonLootDeadline", nil)
				if eligible then
					PlayerData.addCoins(p, 300)
					Progress.addXP(p, "SlayBrute")
				end
				ArenaSessions.leave(p)
				Remotes.Notify:FireClient(p, reason .. (if eligible then " +300 coins." else ""))
			end
		end
	end
	run.World.Folder:Destroy()
	slots[run.Slot] = nil
end
local function resolveLoot(run)
	local loot = run.Loot
	if not loot or loot.Resolved or run.Done then
		return
	end
	loot.Resolved = true
	local contenders = {}
	for _, p in loot.Eligible do
		if p.Parent and memberRun[p] == run and loot.Choices[p] and loot.Choices[p] ~= "Pass" then
			table.insert(contenders, p)
		end
	end
	local winner, best = nil, -1
	local rolls, tied = {}, {}
	local dice = Random.new()
	for _, p in contenders do
		local roll = dice:NextInteger(1, 100)
		table.insert(rolls, p.Name .. " " .. tostring(roll))
		if roll > best then
			best = roll
			tied = { p }
		elseif roll == best then
			table.insert(tied, p)
		end
	end
	if #tied > 0 then
		winner = tied[dice:NextInteger(1, #tied)]
	end
	if winner and not run.Test then
		local rng = Random.new()
		local rarity = if loot.Tier == 5 then "Legendary" else "UltraRare"
		local band = GemRoller.ByRarity[rarity]
		local gem = {
			Source = "PvEDrop",
			Found = os.time(),
			CutMethod = "Natural",
			Id = PlayerData.newGemId(),
			Element = loot.Element,
			Tier = rarity,
			SurgeTier = 4,
			SurgeRank = 3,
			Size = rng:NextInteger(band.Metrics[1], band.Metrics[2]),
			Clarity = rng:NextInteger(band.Metrics[1], band.Metrics[2]),
			Cut = rng:NextInteger(band.Metrics[1], band.Metrics[2]),
		}
		gem.Surge = (if rng:NextNumber() < 0.5 then GemRoller.SurgeVariants else GemRoller.Surges)[gem.Element][4]
		if not PlayerData.addGem(winner, gem) then
			PlayerData.addCoins(winner, 500)
			Remotes.Notify:FireClient(winner, "Gem pouch full: boss gem converted to 500 coins.")
		end
	end
	announce(
		run,
		if winner
			then "BOSS LOOT: " .. winner.Name .. " wins the " .. loot.Element .. " gem. " .. table.concat(rolls, " · ")
			else "Boss loot passed by the squad."
	)
	for _, p in loot.Eligible do
		p:SetAttribute("DungeonLoot", nil)
		p:SetAttribute("DungeonLootDeadline", nil)
	end
	task.delay(5, function()
		finish(run, true, "Colossus defeated. Expedition complete.")
	end)
end
beginLoot = function(run, room)
	if run.Loot or run.Done then
		return
	end
	Duelist.removeDungeon(run.Id) -- clear hostile actors during the reward decision
	if run.Test then
		finish(run, true, "Owner expedition complete. No rewards.")
		return
	end
	local eligible = living(run)
	run.Loot = {
		Eligible = eligible,
		Choices = {},
		Tier = room.GearTier,
		Element = Rules.Roster[room.Theme].Element,
		Deadline = os.clock() + 30,
	}
	for _, p in eligible do
		p:SetAttribute(
			"DungeonLoot",
			(if room.GearTier == 5 then "Legendary" else "Ultra Rare")
				.. " "
				.. GemConfig.elementName(run.Loot.Element)
				.. " Gem · Tier 4 / Rank III"
		)
		p:SetAttribute("DungeonLootDeadline", workspace:GetServerTimeNow() + 30)
	end
	announce(
		run,
		"BOSS DEFEATED · Claim, roll, or pass on the gem. Multiple claims are resolved by a fair party roll. 30 seconds."
	)
	task.delay(30, function()
		resolveLoot(run)
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
	local spec = Rules.Roster[room.Theme]
	for _, p in members do
		p:SetAttribute("DungeonRoom", index)
		p:SetAttribute("DungeonBoss", if room.Boss then spec.Name else nil)
	end
	announce(
		run,
		if room.Boss
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
			Spec = Rules.Roster[kind],
			Boss = room.Boss,
			OnDeath = function()
				if run.Done or (not run.OpenWorld and run.Index ~= index) then
					return
				end
				if run.OpenWorld then
					if room.Boss then
						beginLoot(run, room)
					end
					return
				end
				run.Remaining -= 1
				if run.Remaining > 0 then
					announce(run, string.format("Room %d · %d fighters remaining", index, run.Remaining))
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
				announce(run, string.format("Room %d cleared. Gate open — proceed to room %d.", index, index + 1))
			end,
		})
		if not enemy then
			finish(run, false, "The encounter could not start. Your squad has been returned safely.")
			return
		end
		table.insert(arrivals, enemy.Model)
	end
	ArenaDrop.encounter(members, arrivals, not run.Inserted, run.OpenWorld)
	run.Inserted = true
end
local function safeSpawnRoom(run, index)
	local ok, problem = pcall(spawnRoom, run, index)
	if not ok then
		warn("[Dungeon] encounter failed: " .. tostring(problem))
		finish(run, false, "The encounter failed to load. Please queue again.")
	end
end
local function queue(player, testMode)
	local testing = testMode ~= nil and canTest(player)
	if testMode ~= nil and not testing then
		return Shop.reply(false, "Dungeon testing is restricted to playtest owners.")
	end
	local party = Party.of(player)
	local members = if testing then { player } else party and party.Members or {}
	local allReady = party ~= nil
	for _, p in members do
		if not party or not party.Ready[p] then
			allReady = false
		end
	end
	local ok, why = Rules.canEnter(#members, party ~= nil and party.Leader == player, allReady)
	if not ok and not testing then
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
		Test = testing,
		OpenWorld = testing and testMode == "OpenWorld",
		Slot = slot,
		Index = 1,
		Started = os.clock(),
		Done = false,
	}
	slots[slot] = true
	runs[id] = run
	-- Lock the roster synchronously before any work that could yield.
	for _, p in run.Members do
		memberRun[p] = run
		p:SetAttribute("DungeonId", id)
		p:SetAttribute("DungeonTest", testing)
		p:SetAttribute("RaidId", id)
		p:SetAttribute("PvPEnabled", false)
		p:SetAttribute("CombatSession", "Raid")
	end
	local success, problem = pcall(function()
		for _, p in run.Members do
			ArenaDrop.prepare(p)
		end
		run.Rooms = if run.OpenWorld then Rules.generateOpen(Random.new()) else Rules.generate(Random.new())
		if testing and testMode == "Sahur" then
			run.Rooms = { { Index = 1, X = 0, Z = 0, Boss = true, Theme = 1, Foes = { 1 }, Pillars = 2 } }
		end
		run.World = (if run.OpenWorld then World.buildOpen else World.build)(
			id,
			run.Rooms,
			Vector3.new(2500 + slot * 1400, 0, 2500)
		)
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
			if testing
				then "OWNER TEST  -  solo enabled, no rewards. Orbital deployment inbound."
				else "PATHWAY DUNGEON · Clear five linked canyon encounters. Follow the trail to the Colossus."
		)
		task.delay(0.25, function()
			if run.Done then
				return
			end
			if #living(run) < (if run.Test then 1 else Rules.Min) then
				finish(run, false, "Three players are required to begin. Queue cancelled.")
				return
			end
			if run.OpenWorld then
				ArenaDrop.encounter(living(run), {}, true)
				run.Inserted = true
				for index = 1, #run.Rooms do
					if run.Done then
						break
					end
					safeSpawnRoom(run, index)
				end
				if not run.Done then
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
		warn("[Dungeon] start failed: " .. tostring(problem))
		if not run.World then
			run.World = { Folder = workspace:FindFirstChild("Dungeon_" .. id) or Instance.new("Folder") }
		end
		finish(run, false, "Dungeon setup failed. Please try again.")
		return Shop.reply(false, "Dungeon setup failed.")
	end
	return Shop.reply(true, "Dungeon queued for your ready squad. Deploying now.")
end
function Dungeon.queueParty(player)
	return queue(player)
end
function Dungeon.start()
	Shop.register("DungeonLootChoice", function(player, choice)
		local run = memberRun[player]
		local loot = run and run.Loot
		if not loot or loot.Resolved or not table.find(loot.Eligible, player) then
			return Shop.reply(false, "No eligible boss loot.")
		end
		if os.clock() >= loot.Deadline then
			resolveLoot(run)
			return Shop.reply(false, "Loot voting has ended.")
		end
		if choice ~= "Claim" and choice ~= "Roll" and choice ~= "Pass" then
			return Shop.reply(false, "Choose Claim, Roll or Pass.")
		end
		if loot.Choices[player] then
			return Shop.reply(false, "Your choice is already locked.")
		end
		loot.Choices[player] = choice
		local complete = true
		for _, p in loot.Eligible do
			if p.Parent and memberRun[p] == run and not loot.Choices[p] then
				complete = false
			end
		end
		if complete then
			resolveLoot(run)
		end
		return Shop.reply(true, "Choice locked: " .. choice)
	end)
	Shop.register("PartyDungeon", function(player)
		return queue(player)
	end)
	Shop.register("DungeonTest", function(player, mode)
		if not canTest(player) then
			return Shop.reply(false, "Dungeon testing is restricted to playtest owners.")
		end
		if mode ~= "Sahur" and mode ~= "Full" and mode ~= "OpenWorld" then
			return Shop.reply(false, "Choose Pathway, Open World, or Sahur.")
		end
		return queue(player, mode)
	end)
	ArenaSessions.onDungeonLeave = function(p)
		local run = memberRun[p]
		if not run then
			return
		end
		memberRun[p] = nil
		p:SetAttribute("DungeonId", nil)
		p:SetAttribute("DungeonTest", nil)
		p:SetAttribute("DungeonRoom", nil)
		p:SetAttribute("DungeonBoss", nil)
		p:SetAttribute("DungeonLoot", nil)
		p:SetAttribute("DungeonLootDeadline", nil)
		p:SetAttribute("DungeonObjective", nil)
		if #living(run) == 0 then
			finish(run, false, "The squad has left the dungeon.")
		end
	end
	local function watch(p)
		p:SetAttribute("CanTestDungeon", canTest(p))
		p.CharacterRemoving:Connect(function()
			if memberRun[p] then
				ArenaSessions.leave(p)
			end
		end)
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
			if #alive == 0 then
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
			if not run.OpenWorld and run.Cleared and not run.Done and run.Index < #run.Rooms then
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
