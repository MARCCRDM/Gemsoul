for seed = 1, 1000 do
	local rooms = Rules.generate(Random.new(seed))
	check(#rooms == 5, "Five rooms")
	local used = {}
	for i, r in rooms do
		check(not used[r.X .. ":" .. r.Z], "Room overlap")
		used[r.X .. ":" .. r.Z] = true
		if i > 1 then
			local prev = rooms[i - 1]
			check(math.abs(r.X - prev.X) + math.abs(r.Z - prev.Z) == 1, "Disconnected route")
		end
		check(r.Boss == (i == 5), "Boss must be final")
	end
	check(#rooms[5].Foes == 1 and rooms[5].Theme == rooms[5].Foes[1], "Boss theme must match character")
end
for _, spec in Rules.Roster do
	check(Rules.elementMultiplier(spec.Element, spec.Weakness, spec.Element) == 0.7, "Resistance")
	check(Rules.elementMultiplier(spec.Element, spec.Weakness, spec.Weakness) == 1.3, "Weakness")
	check(Rules.elementMultiplier(spec.Element, spec.Weakness, nil) == 1, "Physical should remain neutral")
end
Dungeon.start()
local solo = squad(1)
check(not handlers.PartyDungeon(solo[1]).Ok, "Solo queued")
local duo = squad(2)
check(not handlers.PartyDungeon(duo[1]).Ok, "Two queued")
local team, party = squad(3)
check(not handlers.PartyDungeon(team[2]).Ok, "Nonleader queued")
party.Ready[team[3]] = false
check(not handlers.PartyDungeon(team[1]).Ok, "Unready party queued")
party.Ready[team[3]] = true
check(handlers.PartyDungeon(team[1]).Ok, "Ready trio rejected")
local id = team[1]:GetAttribute("DungeonId")
check(not handlers.PartyDungeon(team[1]).Ok, "Double queue accepted")
local second = squad(4)
check(handlers.PartyDungeon(second[1]).Ok, "Concurrent squad rejected")
local id2 = second[1]:GetAttribute("DungeonId")
check(id ~= id2, "Instances share IDs")
check((worlds[id].Centers[1] - worlds[id2].Centers[1]).Magnitude > 1000, "Instances overlap")
tick(3)
check(#spawned >= 4, "Fighters not spawned")
local function clearRoom(runId, index)
	local count = 0
	for _, e in table.clone(spawned) do
		if e.Id == runId and e.Encounter.Room == index and not e.Dead then
			e.Dead = true
			e.Encounter.OnDeath()
			count += 1
		end
	end
	return count
end
for room = 1, 4 do
	check(clearRoom(id, room) >= 2, "Missing room fighters")
	check(worlds[id].Gates[room].Destroyed, "Gate stayed closed")
	for _, p in team do
		p.Root.Position = worlds[id].Centers[room + 1] + Vector3.new(0, 4, 0)
	end
	tick(0.5)
end
local boss
for _, e in spawned do
	if e.Id == id and e.Encounter.Boss then
		boss = e
	end
end
check(boss ~= nil, "Final boss not spawned")
clearRoom(id, 5)
for _, p in team do
	check(profiles[p].Coins == 300, "Completion reward missing")
	check(p:GetAttribute("DungeonId") == nil, "Session leaked")
end
boss.Encounter.OnDeath()
check(profiles[team[1]].Coins == 300, "Duplicate reward")
check(worlds[id].Folder.Destroyed and removed[id], "Dungeon not cleaned")
check(second[1]:GetAttribute("DungeonId") == id2, "Another squad interrupted")
for _, p in second do
	ArenaSessions.leave(p)
end
check(worlds[id2].Folder.Destroyed, "Abandoned instance leaked")
local fail = squad(3)
failSpawn = true
check(handlers.PartyDungeon(fail[1]).Ok, "Queue should deploy first")
tick(3)
failSpawn = false
check(fail[1]:GetAttribute("DungeonId") == nil, "Failed spawn did not return squad")
local thin = squad(3)
check(handlers.PartyDungeon(thin[1]).Ok, "Trio failed")
ArenaSessions.leave(thin[3])
tick(3)
check(thin[1]:GetAttribute("DungeonId") == nil, "Countdown began below three")
local lost = squad(3)
handlers.PartyDungeon(lost[1])
tick(3)
local lostId = lost[1]:GetAttribute("DungeonId")
for room = 1, 4 do
	clearRoom(lostId, room)
	if room == 4 then
		ArenaSessions.leave(lost[3])
	end
	for i = 1, 2 do
		lost[i].Root.Position = worlds[lostId].Centers[room + 1] + Vector3.new(0, 4, 0)
	end
	if room < 4 then
		lost[3].Root.Position = worlds[lostId].Centers[room + 1] + Vector3.new(0, 4, 0)
	end
	tick(0.5)
end
check(lost[1]:GetAttribute("DungeonId") == nil, "Boss started below three survivors")
local timeout = squad(3)
handlers.PartyDungeon(timeout[1])
tick(3)
tick(901)
check(timeout[1]:GetAttribute("DungeonId") == nil, "Timeout leaked")
print(
	"PASS: "
		.. checks
		.. " dungeon checks (1,000 connected layouts, roles, elements, queue, readiness, isolation, gates, boss minimum, completion, duplicate rewards, aborts, timeout)"
)
