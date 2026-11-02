-- The intro's dungeon, the Rot Beachhead (Rules.First; Dungeons' "First"
-- mode; run by tests/run_dungeons.py after the dungeon cases): its rooms,
-- its damage by intro pieces won, the run with your kaiju, the knock-down
-- card, the boss and its ending; and as the intro's own (IntroRoundsServer's
-- stage "Dungeon"): its first room and its boss paying the intro's pieces.
do
	local first = Rules.First
	local rooms = Rules.firstRooms()
	local N = #rooms
	check(N == 2, "The intro dungeon is a room of fighters and the nest")
	for i, r in rooms do
		check(r.X == 0 and r.Z == i - 1 and r.Index == i, "The Rot Beachhead's rooms aren't in a line")
		check(r.Boss == (i == N), "The nest isn't last")
		check(r.Name == first.Rooms[i], "A room's name")
		check(#r.Foes >= 1 and r.Theme == r.Foes[1], "A room has no fighters")
	end
	local function idOf(list, index)
		return list[index] and list[index].Id
	end
	check(
		idOf(Rules.Roster, rooms[1].Foes[1]) == "Sahur" and idOf(Rules.Roster, rooms[1].Foes[2]) == "Tralalero" and idOf(Rules.Roster, rooms[1].Foes[3]) == "Patapim",
		"The Breach isn't Sahur, Tralalero and Patapim"
	)
	check(Rules.specOf(rooms[N]).Id == "SahurTrio", "The nest's boss isn't Tung Tung Tung Sahur")
	check(rooms[1].HealthScale < 1 and rooms[1].DamageScale < 1 and rooms[N].DamageScale < 1, "Not softened for a new miner")
	local near = function(a, b)
		return math.abs(a - b) < 1e-6
	end
	check(near(Rules.firstDamage(1), 0.75) and near(Rules.firstDamage(6), 1), "Damage by intro pieces won")
	check(near(Rules.firstDamage(0), 0.75) and near(Rules.firstDamage(40), 1), "Damage outside 1 to 6 pieces")

	-- Off (Config.Features.FirstDungeon): no one gets in, owners too.
	local scout = squad(1)[1]
	permittedTester = scout
	check(not handlers.DungeonTest(scout, "First").Ok and not handlers.FirstDungeon(scout).Ok, "In while it's off")
	check(scout:GetAttribute("DungeonId") == nil, "In while it's off")
	Config.Features.FirstDungeon = true
	-- Into it (from the DEV panel).
	permittedTester = scout
	profiles[scout].IntroRounds = { Won = 2, Losses = 0, Pieces = {} }
	check(not handlers.FirstDungeonRecover(scout).Ok, "RECOVER outside the dungeon")
	local entry = handlers.DungeonTest(scout, "First")
	check(entry.Ok, "The Rot Beachhead didn't start: " .. tostring(entry.Message))
	local id = scout:GetAttribute("DungeonId")
	check(id ~= nil and scout:GetAttribute("DungeonKaiju") == true, "Kaiju aren't let in")
	check(scout:GetAttribute("DungeonRooms") == N and scout:GetAttribute("DungeonTest") == nil, "The strip's room count, or shown as a test run")
	local told
	for _, sentEvent in sent[scout] do
		if sentEvent[1] == "FirstDungeon" and sentEvent[2].Phase == "In" then
			told = sentEvent[2]
		end
	end
	check(told ~= nil and told.RoundsLeft == 4, "Not told it's in, with the rounds left (LEAVE's card)")
	tick(3)
	local fighters = {}
	for _, e in spawned do
		if e.Id == id and e.Encounter.Room == 1 then
			table.insert(fighters, e)
		end
	end
	check(#fighters >= 1, "Room 1's fighters didn't come")
	check(scout:GetAttribute("DungeonPhase") == "Fight" and scout:GetAttribute("DungeonFoesLeft") == #fighters and scout:GetAttribute("DungeonFoesTotal") == #fighters, "The tracker's room state")
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
	local quit = handlers.FirstDungeonQuit(scout, "Intro")
	check(quit.Ok and quit.To == "Intro", "FINISH THE INTRO FIGHTS refused")
	check(scout:GetAttribute("DungeonId") == nil and scout:GetAttribute("DungeonKaiju") == nil, "Quit didn't leave")
	check(scout:GetAttribute("CombatSession") == nil and profiles[scout].Coins == 0, "Quit left you in or paid you")
	check(not scout.Root.Anchored, "Quit left you held")
	check(not handlers.FirstDungeonQuit(scout).Ok, "Quit outside the dungeon")

	-- Through it: two rooms, the nest (enraged at half health: its rot-spawn
	-- join in), the victory card, the boss cache, then out with the clear's rewards.
	local plainSpawn = Duelist.spawnDungeon
	Duelist.spawnDungeon = function(...)
		local e = plainSpawn(...)
		if e then
			e.Humanoid = { Health = 100, MaxHealth = 100, HealthChanged = signal() }
		end
		return e
	end
	scout.Humanoid.Health = scout.Humanoid.MaxHealth
	check(handlers.DungeonTest(scout, "First").Ok, "The Rot Beachhead didn't start again")
	id = scout:GetAttribute("DungeonId")
	tick(3)
	local caches = #bossCaches
	for room = 1, N - 1 do
		check(clearRoom(id, room) >= 1, "Room " .. room .. " had nobody to clear")
		check(scout:GetAttribute("DungeonPhase") == "Move", "Not told to move on after room " .. room)
		check(#introWins == 0, "A piece paid outside the intro's own run")
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
	local before = #spawned
	nest.Humanoid.Health = 70
	nest.Humanoid.HealthChanged.Fire(70)
	check(#spawned == before, "Enraged too early")
	nest.Humanoid.Health = 45
	nest.Humanoid.HealthChanged.Fire(45)
	check(#spawned == before + #first.Enrage.Adds, "The enraged boss's rot-spawn didn't come")
	check(scout:GetAttribute("DungeonFoesLeft") == 1 + #first.Enrage.Adds, "The tracker's count with the rot-spawn in")
	nest.Humanoid.HealthChanged.Fire(30)
	check(#spawned == before + #first.Enrage.Adds, "Enraged twice")
	sent[scout] = {}
	nest.Dead = true
	nest.Encounter.OnDeath()
	check(#bossCaches == caches, "Loot before the rot-spawn were down")
	clearRoom(id, N)
	local won
	for _, sentEvent in sent[scout] do
		if sentEvent[1] == "FirstDungeon" and sentEvent[2].Phase == "Won" then
			won = sentEvent[2]
		end
	end
	check(won ~= nil and won.Boss == "Tung Tung Tung Sahur" and won.Seconds == first.WinSeconds, "No victory card")
	check(won.RoundsLeft == 4 and type(won.Time) == "number" and won.Downs == 0, "The victory card's numbers")
	check(scout:GetAttribute("DungeonPhase") == "Loot", "The tracker's not on the loot")
	check(#bossCaches == caches + 1 and bossCaches[#bossCaches].Player == scout, "No boss cache")
	check(scout:GetAttribute("DungeonId") == id, "Out before the cache")
	tick(first.WinSeconds - 1)
	check(scout:GetAttribute("DungeonId") == id, "Out before the victory card's time")
	tick(1.1)
	check(scout:GetAttribute("DungeonId") == nil, "Not back out after the nest")
	check(profiles[scout].Coins > 0, "No rewards for clearing the Rot Beachhead")
	check(scout:GetAttribute("DungeonPhase") == nil and scout:GetAttribute("DungeonFoesLeft") == nil, "The tracker's state left on")
	-- CONTINUE on the victory card: out at once, rewards and all.
	local coins = profiles[scout].Coins
	check(not handlers.FirstDungeonDone(scout).Ok, "CONTINUE outside the dungeon")
	check(handlers.DungeonTest(scout, "First").Ok, "The Rot Beachhead didn't start a third time")
	id = scout:GetAttribute("DungeonId")
	tick(3)
	check(not handlers.FirstDungeonDone(scout).Ok, "CONTINUE before the boss is down")
	for room = 1, N - 1 do
		clearRoom(id, room)
		scout.Root.Position = worlds[id].Centers[room + 1] + Vector3.new(0, 4, 0)
		tick(0.6)
	end
	clearRoom(id, N)
	clearRoom(id, N) -- (the enraged boss's rot-spawn, if it got that far)
	local done = handlers.FirstDungeonDone(scout)
	check(done.Ok and done.To == "Intro" and scout:GetAttribute("DungeonId") == nil, "CONTINUE didn't take you out")
	check(profiles[scout].Coins > coins, "CONTINUE skipped the rewards")
	Duelist.spawnDungeon = plainSpawn
	-- Open to everyone (Config.Features.FirstDungeon), not before; GO TO LOBBY any time.
	local miner = squad(1)[1]
	check(handlers.FirstDungeon(miner).Ok, "A player couldn't get in while it's on")
	check(miner:GetAttribute("DungeonId") ~= nil, "Not in")
	tick(3)
	local out = handlers.FirstDungeonQuit(miner, "Lobby")
	check(out.Ok and out.To == "Lobby" and miner:GetAttribute("DungeonId") == nil, "GO TO LOBBY didn't leave")
	check(profiles[miner].Coins == 0, "Leaving paid out")
	Config.Features.FirstDungeon = nil

	-- The intro's own run: its 1v1s won (IntroRoundsServer's stage), in with
	-- the switch off; the first room pays a piece, the boss the rest (no boss
	-- cache, no victory card: the intro's roll cards), the knock-down and
	-- LEAVE cards offer the lobby only, and TO THE LOBBY takes you out.
	local rookie = squad(1)[1]
	profiles[rookie].IntroRounds = { Won = 2, Losses = 0, Pieces = {} }
	check(not handlers.FirstDungeon(rookie).Ok, "In before the intro's 1v1s were won")
	introStages[rookie] = "Dungeon"
	Duelist.spawnDungeon = function(...)
		local e = plainSpawn(...)
		if e then
			e.Humanoid = { Health = 100, MaxHealth = 100, HealthChanged = signal() }
		end
		return e
	end
	check(handlers.FirstDungeon(rookie).Ok, "The intro's dungeon refused with its 1v1s won")
	id = rookie:GetAttribute("DungeonId")
	local inEvent
	for _, sentEvent in sent[rookie] do
		if sentEvent[1] == "FirstDungeon" and sentEvent[2].Phase == "In" then
			inEvent = sentEvent[2]
		end
	end
	check(inEvent and inEvent.RoundsLeft == 0, "The intro's run offers the intro fights")
	tick(3)
	clearRoom(id, 1)
	check(#introWins == 1 and introWins[1][1] == rookie and introWins[1][2] == "Room", "The first room didn't pay the intro's piece")
	rookie.Root.Position = worlds[id].Centers[N] + Vector3.new(0, 4, 0)
	tick(0.6)
	sent[rookie] = {}
	local caches2 = #bossCaches
	clearRoom(id, N)
	clearRoom(id, N)
	check(#introWins == 2 and introWins[2][2] == "Boss", "The boss didn't pay the rest of the set")
	check(#bossCaches == caches2, "A boss cache on top of the intro's pieces")
	for _, sentEvent in sent[rookie] do
		check(not (sentEvent[1] == "FirstDungeon" and sentEvent[2].Phase == "Won"), "The victory card over the intro's roll cards")
	end
	check(rookie:GetAttribute("DungeonId") == id, "Out before the roll cards")
	local coins2 = profiles[rookie].Coins
	local done2 = handlers.FirstDungeonDone(rookie)
	check(done2.Ok and rookie:GetAttribute("DungeonId") == nil, "TO THE LOBBY didn't take you out")
	check(profiles[rookie].Coins > coins2, "No clear rewards for the intro's dungeon")
	-- (left early: the lobby, and the dungeon waits)
	introStages[rookie] = "Dungeon"
	check(handlers.FirstDungeon(rookie).Ok, "The intro's dungeon refused a second time")
	tick(3)
	local quitIntro = handlers.FirstDungeonQuit(rookie, "Intro")
	check(quitIntro.Ok and quitIntro.To == "Lobby", "The intro's run went back to the intro fights")
	Duelist.spawnDungeon = plainSpawn
	introStages[rookie] = nil
	print("PASS: the Rot Beachhead: rooms, damage by intro pieces, kaiju let in, the knock-down card, RECOVER, back to the intro fights, boss cache and rewards, the intro's own run (pieces in the first room and from the boss, lobby-only exits), the tracker, the enraged boss, the victory card and CONTINUE, on and off by its switch, GO TO LOBBY")
end
