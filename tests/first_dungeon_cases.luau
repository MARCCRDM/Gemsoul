-- The campaign's first dungeon, the Rot Beachhead (Rules.First; Dungeons'
-- "First" test mode; run by tests/run_dungeons.py after the dungeon cases):
-- its rooms, its damage by intro pieces won, the run with your kaiju, the
-- knock-down card (RECOVER, back to the intro fights) and the boss cache.
do
	local first = Rules.First
	local rooms = Rules.firstRooms()
	check(#rooms == 3, "The Rot Beachhead is two rooms and a nest")
	for i, r in rooms do
		check(r.X == 0 and r.Z == i - 1 and r.Index == i, "The Rot Beachhead's rooms aren't in a line")
		check(r.Boss == (i == 3), "The nest isn't last")
		check(r.Name == first.Rooms[i], "A room's name")
		check(#r.Foes >= 1 and r.Theme == r.Foes[1], "A room has no fighters")
	end
	local function idOf(list, index)
		return list[index] and list[index].Id
	end
	check(idOf(Rules.Roster, rooms[1].Foes[1]) == "Sahur", "Room 1 isn't Sahur")
	check(
		idOf(Rules.Roster, rooms[2].Foes[1]) == "Tralalero" and idOf(Rules.Roster, rooms[2].Foes[2]) == "Patapim",
		"Room 2 isn't Tralalero and Patapim"
	)
	check(idOf(Rules.Bosses, rooms[3].Theme) == first.Boss, "The nest's boss isn't " .. first.Boss)
	check(rooms[1].HealthScale < 1 and rooms[1].DamageScale < 1 and rooms[3].DamageScale < 1, "Not softened for a new miner")
	local near = function(a, b)
		return math.abs(a - b) < 1e-6
	end
	check(near(Rules.firstDamage(1), 0.75) and near(Rules.firstDamage(6), 1), "Damage by intro pieces won")
	check(near(Rules.firstDamage(0), 0.75) and near(Rules.firstDamage(40), 1), "Damage outside 1 to 6 pieces")

	-- Into it (an owner's test, from the DEV panel).
	local scout = squad(1)[1]
	permittedTester = scout
	profiles[scout].IntroRounds = { Won = 2, Losses = 0, Pieces = {} }
	check(not handlers.FirstDungeonRecover(scout).Ok, "RECOVER outside the dungeon")
	local entry = handlers.DungeonTest(scout, "First")
	check(entry.Ok, "The Rot Beachhead didn't start: " .. tostring(entry.Message))
	local id = scout:GetAttribute("DungeonId")
	check(id ~= nil and scout:GetAttribute("DungeonKaiju") == true, "Kaiju aren't let in")
	tick(3)
	local fighters = {}
	for _, e in spawned do
		if e.Id == id and e.Encounter.Room == 1 then
			table.insert(fighters, e)
		end
	end
	check(#fighters >= 1, "Room 1's fighters didn't come")
	local enc = fighters[1].Encounter
	check(enc.KaijuFoes == true, "Your kaiju can't fight them")
	check(near(enc.HealthScale, first.FighterHealth), "Room 1's health isn't softened")
	check(near(enc.DamageScale, first.FighterDamage * Rules.firstDamage(2)), "Room 1's damage isn't by pieces won")

	-- Knocked down: shielded, down, then the card (rounds left to win).
	local function hit()
		return dungeonLethal(scout, scout.Humanoid)
	end
	sent[scout] = {}
	check(hit() == true, "A lethal blow wasn't caught")
	check(scout.Humanoid.Health == 1 and scout:GetAttribute("SparDown") ~= nil, "Not knocked down")
	check(hit() == true and scout.Humanoid.Health == 1, "A second blow while down got through")
	tick(first.DownSeconds + 0.1)
	local card
	for _, s in sent[scout] do
		if s[1] == "FirstDungeon" then
			card = s[2]
		end
	end
	check(card ~= nil and card.Phase == "Down", "No knock-down card")
	check(card.RoundsLeft == 4, "Rounds left to win: " .. tostring(card.RoundsLeft))
	check(card.Room == first.Rooms[1] and card.Seconds == first.ChooseSeconds, "The card's room and time")
	check(scout.Root.Anchored == true and scout:GetAttribute("SparDown") == nil, "Not held while choosing")

	-- RECOVER: up at the room's start, full health, its fighters at full.
	scout.Root.Position = Vector3.new(0, 0, 0)
	check(handlers.FirstDungeonRecover(scout).Ok, "RECOVER refused")
	check(scout.Humanoid.Health == scout.Humanoid.MaxHealth and not scout.Root.Anchored, "RECOVER didn't heal and free you")
	check(healedDungeons[id] == 1, "RECOVER didn't heal the room's fighters")
	check((scout.Root.Position - worlds[id].Centers[1]).Magnitude < 30, "RECOVER didn't put you at the room's start")
	check(not handlers.FirstDungeonRecover(scout).Ok, "RECOVER twice")

	-- Left to choose: RECOVER by itself.
	hit()
	tick(first.DownSeconds + first.ChooseSeconds + 1)
	check(scout.Humanoid.Health == scout.Humanoid.MaxHealth and not scout.Root.Anchored, "No RECOVER by itself")
	check(scout:GetAttribute("DungeonId") == id, "Out of the dungeon after recovering")

	-- Back to the intro fights: out, and no rewards.
	hit()
	tick(first.DownSeconds + 0.1)
	check(handlers.FirstDungeonQuit(scout).Ok, "FINISH THE INTRO FIGHTS refused")
	check(scout:GetAttribute("DungeonId") == nil and scout:GetAttribute("DungeonKaiju") == nil, "Quit didn't leave")
	check(scout:GetAttribute("CombatSession") == nil and profiles[scout].Coins == 0, "Quit left you in or paid you")
	check(not scout.Root.Anchored, "Quit left you held")
	check(not handlers.FirstDungeonQuit(scout).Ok, "Quit outside the dungeon")

	-- Through it: two rooms, the nest, the boss cache, then out with the clear's rewards.
	scout.Humanoid.Health = scout.Humanoid.MaxHealth
	check(handlers.DungeonTest(scout, "First").Ok, "The Rot Beachhead didn't start again")
	id = scout:GetAttribute("DungeonId")
	tick(3)
	local caches = #bossCaches
	for room = 1, 2 do
		check(clearRoom(id, room) >= 1, "Room " .. room .. " had nobody to clear")
		scout.Root.Position = worlds[id].Centers[room + 1] + Vector3.new(0, 4, 0)
		tick(0.6)
	end
	local nest
	for _, e in spawned do
		if e.Id == id and e.Encounter.Boss then
			nest = e
		end
	end
	check(nest ~= nil and nest.Encounter.KaijuFoes == true, "The nest's boss didn't come")
	check(near(nest.Encounter.HealthScale, first.BossHealth), "The boss isn't softened")
	clearRoom(id, 3)
	check(#bossCaches == caches + 1 and bossCaches[#bossCaches].Player == scout, "No boss cache")
	check(scout:GetAttribute("DungeonId") == id, "Out before the cache")
	tick(6.1)
	check(scout:GetAttribute("DungeonId") == nil, "Not back out after the nest")
	check(profiles[scout].Coins > 0, "No rewards for clearing the Rot Beachhead")
	print("PASS: the Rot Beachhead: rooms, damage by intro pieces, kaiju let in, the knock-down card, RECOVER, back to the intro fights, boss cache and rewards")
end
