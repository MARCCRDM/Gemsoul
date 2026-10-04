-- Same-server, opt-in matchmaking: three solos or a ready duo plus a solo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Party = require(script.Parent.Party)
local Raids = require(script.Parent.Raids)
local Dungeon = require(script.Parent.Dungeons)
local Shop = require(script.Parent.Shop)
local Remotes = require(script.Parent.Remotes)
local Queue = {}
local entries = {}
local function remove(index, message)
	local entry = table.remove(entries, index)
	for _, p in entry.Members do
		p:SetAttribute("DungeonQueue", nil)
		if message and p.Parent then
			Remotes.Notify:FireClient(p, message)
		end
	end
	return entry
end
local function valid(entry)
	local group = Party.of(entry.Leader)
	if group ~= entry.Party then
		return false
	end
	if group and (#group.Members ~= #entry.Members or group.Leader ~= entry.Leader) then
		return false
	end
	for _, p in entry.Members do
		if not p.Parent or Raids.busy(p) or Party.of(p) ~= entry.Party then
			return false
		end
		if group and (not table.find(group.Members, p) or not group.Ready[p]) then
			return false
		end
	end
	return true
end
local function cancel(player)
	for i = #entries, 1, -1 do
		if table.find(entries[i].Members, player) then
			remove(i, "Dungeon search cancelled.")
			return Shop.reply(true, "Search cancelled.")
		end
	end
	return Shop.reply(false, "You are not searching.")
end
function Queue.step()
	for i = #entries, 1, -1 do
		if not valid(entries[i]) then
			remove(i, "Dungeon search cancelled: squad or readiness changed.")
		end
	end
	-- Find the earliest compatible group without skipping a duo's friend.
	for i, first in entries do
		local chosen = { i }
		local count = #first.Members
		for j = i + 1, #entries do
			if count + #entries[j].Members <= 3 then
				table.insert(chosen, j)
				count += #entries[j].Members
			end
			if count == 3 then
				break
			end
		end
		if count == 3 then
			local members = {}
			for _, index in chosen do
				for _, p in entries[index].Members do
					table.insert(members, p)
				end
			end
			-- Remove reservations before any party chat setup or dungeon spawn can yield.
			for n = #chosen, 1, -1 do
				remove(chosen[n])
			end
			local party = Party.matchDungeon(members)
			local result = if party
				then Dungeon.queueParty(party.Leader)
				else { Ok = false, Message = "Squad changed. Please search again." }
			for _, p in members do
				if p.Parent then
					Remotes.Notify:FireClient(
						p,
						if result.Ok then "Squad found! Entering the dungeon." else result.Message
					)
				end
			end
			return
		end
	end
end
local function join(player)
	if player:GetAttribute("DungeonQueue") then
		return Shop.reply(false, "Already searching.")
	end
	local party = Party.of(player)
	if party and party.Leader ~= player then
		return Shop.reply(false, "Your party leader starts the search.")
	end
	local members = if party then party.Members else { player }
	if #members > 3 then
		return Shop.reply(false, "Random dungeon squads have three slots. Use the normal party launch for four.")
	end
	for _, p in members do
		if p:GetAttribute("DungeonQueue") or Raids.busy(p) then
			return Shop.reply(false, "A squad member is busy or already searching.")
		end
		if party and not party.Ready[p] then
			return Shop.reply(false, "Everyone in your friend party must mark Ready before searching.")
		end
	end
	local entry = { Leader = player, Party = party, Members = table.clone(members) }
	table.insert(entries, entry)
	for _, p in members do
		p:SetAttribute("DungeonQueue", true)
	end
	return Shop.reply(
		true,
		"Searching this server for " .. tostring(3 - #members) .. " teammates. You will deploy automatically when full."
	)
end
function Queue.start()
	Shop.register("DungeonFind", join)
	Shop.register("DungeonCancel", cancel)
	Players.PlayerRemoving:Connect(cancel)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			Queue.step()
		end
	end)
end
return Queue
