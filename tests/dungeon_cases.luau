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
	check(Rules.elementMultiplier(spec.Element, spec.Weakness, spec.Element) == 0.75, "Resistance")
	check(Rules.elementMultiplier(spec.Element, spec.Weakness, spec.Weakness) == 1.25, "Weakness")
	check(Rules.elementMultiplier(spec.Element, spec.Weakness, nil) == 1, "Physical should remain neutral")
end
-- Armor gems: each resists its own element by quality; the main element is
-- weak to the element that beats it (ElementMatchup).
do
	local function gem(element, grade)
		return { Element = element, Size = grade, Clarity = grade, Cut = grade }
	end
	local near = function(a, b)
		return math.abs(a - b) < 1e-6
	end
	check(near(ElementMatchup.gemResist(gem("Fire", 1)), 0.035), "Lowest-grade gem resists 3.5%")
	check(near(ElementMatchup.gemResist(gem("Fire", 10)), 0.08), "Top-grade gem resists 8%")
	local one = ElementMatchup.profile({ ArmorGem = gem("Fire", 10) })
	check(one.Main == "Fire" and near(ElementMatchup.against("Fire", one), 0.92), "One Thermal gem resists 8%")
	check(near(ElementMatchup.against("Poison", one), 1.25), "Thermal armor is weak to Corrosive")
	check(
		near(ElementMatchup.against("Frost", one), 1) and select(2, ElementMatchup.against("Frost", one)) == nil,
		"Neutral"
	)
	check(near(ElementMatchup.against(nil, one), 1), "Physical neutral")
	local full = {}
	for _, slot in ElementMatchup.Slots do
		full[slot .. "Gem"] = gem("Fire", 10)
	end
	check(near(ElementMatchup.profile(full).Resist.Fire, 0.35), "Five top gems capped at 35%")
	-- Mixed: two Thermal, one Corrosive; Thermal is main, Corrosive softened.
	local mixed = ElementMatchup.profile({
		HelmetGem = gem("Fire", 10),
		ArmorGem = gem("Fire", 10),
		BootsGem = gem("Poison", 10),
	})
	check(mixed.Main == "Fire", "Main element is the most resisted")
	check(near(ElementMatchup.against("Poison", mixed), 0.92 * 1.25), "Resisting your weakness softens it")
	check(near(ElementMatchup.against("Fire", ElementMatchup.profile({})), 1), "No armor gems: neutral")
	local rough = ElementMatchup.gemResist({ Element = "Frost", Size = 10, Clarity = 10 })
	check(near(rough, 0.08), "A rough gem grades on Size and Clarity")
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
check(#encounterDrops == 2, "Expected one pod timeline per squad, not one per enemy")
for _, drop in encounterDrops do
	check(
		drop.IncludeParty and not drop.Background and #drop.Foes >= 2,
		"First pathway encounter must drop squad and enemies"
	)
	for _, p in drop.Members do
		check(preparedDrops[p], "Dungeon player not concealed for teleport")
	end
end
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
-- Public queues use gated pathway progression, not the experimental open map.
local function reachBoss(runId, members)
	for room = 1, 4 do
		check(clearRoom(runId, room) >= 2, "Missing pathway encounter")
		check(worlds[runId].Gates[room].Destroyed, "Pathway gate stayed sealed")
		for _, p in members do
			p.Root.Position = worlds[runId].Centers[room + 1] + Vector3.new(0, 4, 0)
		end
		tick(0.5)
		local drop = encounterDrops[#encounterDrops]
		check(not drop.IncludeParty and not drop.Background and #drop.Foes > 0, "Later rooms must drop only enemies")
	end
end
for _, e in spawned do
	if e.Id == id then
		check(not e.Encounter.OpenWorld and e.Encounter.Room == 1, "Public queue enabled open world")
	end
end
reachBoss(id, team)
local boss
for _, e in spawned do
	if e.Id == id and e.Encounter.Boss then
		boss = e
	end
end
check(boss ~= nil, "Final boss not spawned")
clearRoom(id, 5)
check(team[1]:GetAttribute("DungeonLoot") ~= nil, "Boss loot prompt missing")
check(not handlers.DungeonLootChoice(second[1], "Claim").Ok, "Other squad stole loot")
check(not handlers.DungeonLootChoice(team[1], "Invalid").Ok, "Invalid choice accepted")
check(handlers.DungeonLootChoice(team[1], "Claim").Ok, "Claim refused")
check(not handlers.DungeonLootChoice(team[1], "Roll").Ok, "Duplicate choice accepted")
check(handlers.DungeonLootChoice(team[2], "Roll").Ok, "Roll refused")
check(handlers.DungeonLootChoice(team[3], "Pass").Ok, "Pass refused")
check(#awarded == 1 and awarded[1].Player ~= team[3], "Loot duplicated or awarded to passer")
check(awarded[1].Gem.SurgeTier == 4 and awarded[1].Gem.SurgeRank == 3, "Boss gem quality")
tick(5)
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
ArenaSessions.leave(lost[3])
for i = 1, 2 do
	lost[i].Root.Position = worlds[lostId].Centers[1]
end
tick(0.5)
check(lost[1]:GetAttribute("DungeonId") == lostId, "Losing a member prematurely destroyed open map")
for i = 1, 2 do
	ArenaSessions.leave(lost[i])
end
local timeout = squad(3)
handlers.PartyDungeon(timeout[1])
tick(3)
tick(901)
check(timeout[1]:GetAttribute("DungeonId") == nil, "Timeout leaked")
print(
	"PASS: "
		.. checks
		.. " dungeon checks (1,000 connected layouts, roles, elements, queue, readiness, isolation, pathway progression, loot choices, completion, duplicate rewards, aborts, timeout)"
)

local tester = squad(1)[1]
check(not handlers.DungeonTest(tester, "Sahur").Ok, "Live server accepted test request")
check(not handlers.PartyDungeon(tester, "Sahur").Ok, "Extra queue argument bypassed party minimum")
studioMode = true
check(not handlers.DungeonTest(tester, "Bad").Ok, "Invalid test mode accepted")
check(handlers.DungeonTest(tester, "Sahur").Ok, "Studio solo boss rejected")
local testId = tester:GetAttribute("DungeonId")
tick(3)
check(tester:GetAttribute("DungeonBoss") == "Tung Tung Tung Sahur", "Wrong test boss")
clearRoom(testId, 1)
check(tester:GetAttribute("DungeonId") == nil, "Solo test failed cleanup")
check(tester:GetAttribute("DungeonTest") == nil, "Test flag leaked")
check(profiles[tester].Coins == 0, "Studio test awarded coins")
print("PASS: Studio test entry, live rejection, solo boss and cleanup")

studioMode = false
permittedTester = tester
check(handlers.DungeonTest(tester, "Sahur").Ok, "Authorized live tester rejected")
local liveId = tester:GetAttribute("DungeonId")
tick(3)
clearRoom(liveId, 1)
check(profiles[tester].Coins == 0, "Live test awarded coins")
check(tester:GetAttribute("DungeonId") == nil, "Live test did not clean up")
local outsider = squad(1)[1]
outsider:SetAttribute("CanTestDungeon", true)
check(not handlers.DungeonTest(outsider, "Sahur").Ok, "Forged permission attribute bypassed server authorization")
check(not handlers.PartyDungeon(tester).Ok, "Owner bypassed normal queue minimum")
print("PASS: published owner tests, unauthorized rejection, reward suppression, normal queue minimum")

for seed = 1, 1000 do
	local camps = Rules.generateOpen(Random.new(seed))
	check(#camps == 10 and camps[10].Boss, "Open boss layout")
	local neutral = 0
	for i, camp in camps do
		if camp.Bandit then
			neutral += 1
		end
		check(
			math.abs(camp.X * Rules.Spacing) < Rules.OpenRadius - 30
				and math.abs(camp.Z * Rules.Spacing) < Rules.OpenRadius - 30,
			"Camp outside map"
		)
		check(camp.GearTier >= 1 and camp.GearTier <= 5, "Invalid camp difficulty")
	end
	check(neutral == 3, "Bandit camp count")
end
print("PASS: 1,000 open-map populations, camp bounds, randomized difficulty and bandit groups")

-- An unanswered offer expires safely; a full pouch gets the disclosed coin fallback.
local quiet = squad(3)
handlers.PartyDungeon(quiet[1])
tick(3)
local quietId = quiet[1]:GetAttribute("DungeonId")
local before = #awarded
reachBoss(quietId, quiet)
clearRoom(quietId, 5)
tick(30)
tick(5)
check(#awarded == before and quiet[1]:GetAttribute("DungeonId") == nil, "Unanswered loot leaked or awarded")
local full = squad(3)
handlers.PartyDungeon(full[1])
tick(3)
local fullId = full[1]:GetAttribute("DungeonId")
reachBoss(fullId, full)
clearRoom(fullId, 5)
local add = PlayerData.addGem
PlayerData.addGem = function()
	return false
end
handlers.DungeonLootChoice(full[1], "Claim")
handlers.DungeonLootChoice(full[2], "Pass")
handlers.DungeonLootChoice(full[3], "Pass")
PlayerData.addGem = add
tick(5)
check(profiles[full[1]].Coins == 800, "Full pouch fallback lost reward")
check(not handlers.DungeonLootChoice(full[1], "Roll").Ok, "Resolved loot replay accepted")
print("PASS: loot timeout, full inventory compensation, single claimant and replay rejection")

-- Explicit owner-only open-world mode remains available alongside Full/Pathway.
check(not handlers.DungeonTest(outsider, "OpenWorld").Ok, "Public open-world test bypass")
local beforeOpenDrops = #encounterDrops
check(handlers.DungeonTest(tester, "OpenWorld").Ok, "Owner open-world test rejected")
local openId = tester:GetAttribute("DungeonId")
tick(3)
local entry = encounterDrops[beforeOpenDrops + 1]
check(
	entry.IncludeParty and not entry.Background and #entry.Foes == 0,
	"Open-world squad needs one arrival at landing zone"
)
check(#encounterDrops > beforeOpenDrops + 1, "Open-world enemies missing pod arrivals")
for i = beforeOpenDrops + 2, #encounterDrops do
	check(encounterDrops[i].Background and not encounterDrops[i].IncludeParty, "Ambient camp stole squad camera")
end
local population = 0
for _, e in spawned do
	if e.Id == openId then
		check(e.Encounter.OpenWorld, "Wrong test mode")
		population += 1
	end
end
check(population >= 19, "Open-world test population missing")
check(worlds[openId].Origin ~= nil, "Open-world builder not selected")
clearRoom(openId, 10)
check(tester:GetAttribute("DungeonId") == nil and profiles[tester].Coins == 0, "Open test cleanup/rewards")
check(handlers.DungeonTest(tester, "Full").Ok, "Pathway test rejected")
local pathId = tester:GetAttribute("DungeonId")
tick(3)
for _, e in spawned do
	if e.Id == pathId then
		check(not e.Encounter.OpenWorld and e.Encounter.Room == 1, "Full should mean pathway")
	end
end
ArenaSessions.leave(tester)
print("PASS: public pathway default, owner-only open-world mode, separate pathway test and reward suppression")
