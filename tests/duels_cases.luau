local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

Duels.start()

-- The shared rules -------------------------------------------------------------
check(math.abs(Matchmaking.expected(1000, 1000) - 0.5) < 1e-9, "Even ratings aren't a coin flip")
check(Matchmaking.rated(1000, 1000, true) == 1016 and Matchmaking.rated(1000, 1000, false) == 984, "Elo step")
check(Matchmaking.rated(1400, 1000, true) < 1400 + 5, "An expected win paid like an upset")
check(
	Matchmaking.window(0) == 100 and Matchmaking.window(20) == 600 and Matchmaking.window(999) == 1000,
	"Rating window"
)
local entries = {
	{ Rating = 1000, Since = 0, Size = 1 },
	{ Rating = 1500, Since = 1, Size = 1 },
	{ Rating = 1050, Since = 2, Size = 1 },
	{ Rating = 1000, Since = 3, Size = 2 },
}
local pairs = Matchmaking.pair(entries, 5)
check(#pairs == 1 and pairs[1][1] == 1 and pairs[1][2] == 3, "Closest rating within the window, sizes kept apart")
check(#Matchmaking.pair(entries, 30) == 1, "A wide gap paired before the window allowed it")
check(
	#Matchmaking.pair({ entries[1], { Rating = 1500, Since = 0, Size = 1 } }, 20) == 1,
	"A long wait never widened the window"
)
local function stub(attrs)
	return {
		GetAttribute = function(_, k)
			return attrs[k]
		end,
	}
end
check(Matchmaking.versus(stub({}), stub({})), "Two strangers can't fight in the Arena")
check(not Matchmaking.versus(stub({ PartyId = "1" }), stub({ PartyId = "1" })), "Party members can hurt each other")
check(Matchmaking.versus(stub({ PartyId = "1" }), stub({ PartyId = "2" })), "Different parties can't fight")
check(not Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({})), "A duellist hit an outsider")
check(
	not Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({ MatchId = "D2", MatchTeam = 2 })),
	"Duellists in different matches fight"
)
check(
	not Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({ MatchId = "D1", MatchTeam = 1 })),
	"Teammates fight"
)
check(
	Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({ MatchId = "D1", MatchTeam = 2 })),
	"Opponents can't fight"
)
local a1 = Matchmaking.lane(1, 1, 1, 1)
local b1 = Matchmaking.lane(1, 2, 1, 1)
check(math.abs((a1 - b1).Magnitude - 40) < 1e-6, "Opponents don't face off 40 studs apart, as in the intro")
check((a1 + b1).Magnitude < 1e-6, "Opponents aren't across the floor's centre")
local t1, t2 = Matchmaking.lane(2, 1, 1, 2), Matchmaking.lane(2, 1, 2, 2)
local o1 = Matchmaking.lane(2, 2, 1, 2)
check(
	math.abs((t1 - t2).Magnitude - 5) < 1e-6
		and math.abs((t1.X - t2.X) * (o1.X - t1.X) + (t1.Z - t2.Z) * (o1.Z - t1.Z)) < 1e-6,
	"Teammates don't stand side by side"
)
for slot = 1, Matchmaking.Lanes do
	for team = 1, 2 do
		for index = 1, 2 do
			check(Matchmaking.lane(slot, team, index, 2).Magnitude < 28, "A lane spot is off the 30-stud floor")
		end
	end
end
check(Season.XP.DuelWin and Season.XP.DuelPlay, "Duel XP missing")

-- 1v1 queue: two players are matched, fight, and the winner is rated ----------
local ana, ben = makePlayer(1, "Ana"), makePlayer(2, "Ben")
local r = handlers.DuelQueue(ana, "1v1")
check(r.Ok and ana:GetAttribute("DuelQueue") == "1v1" and last(ana, "Queue")[2].Mode == "1v1", "Ana not queued")
check(not handlers.DuelQueue(ana, "3v3").Ok, "Unknown mode accepted")
advance(0.25)
check(Duels.matchOf(ana) == nil, "A lone player was matched")
check(handlers.DuelQueue(ben, "1v1").Ok, "Ben not queued")
advance(0.25)
local match = Duels.matchOf(ana)
check(match ~= nil and match == Duels.matchOf(ben) and match.Ranked, "Queue didn't start a ranked match")
check(
	ana:GetAttribute("CombatSession") == "Duel" and ana:GetAttribute("PvPEnabled") == true,
	"Not put in a duel session"
)
check(
	ana:GetAttribute("MatchId") == match.Id and ana:GetAttribute("MatchTeam") ~= ben:GetAttribute("MatchTeam"),
	"Match ids or teams wrong"
)
check(ana:GetAttribute("DuelQueue") == nil and last(ana, "Queue")[2] == nil, "Still shown as queued")
check(
	math.abs((ana.Root.Position - ben.Root.Position).Magnitude - 40) < 0.001,
	"Online 1v1 must use the default 40-stud face-off spots"
)
check(resets[ana] and resets[ben], "Combat state not reset for the duel")
local info = last(ana, "Match")[2]
check(info.Mode == "1v1" and info.Ranked and #info.Teams == 2 and info.Teams[2][1].Name == "Ben", "Match info wrong")
-- Ranked: even stats, rarity capped at Ultra Rare, said on the match screen.
check(
	ana:GetAttribute("MatchStats") == "Even" and ana:GetAttribute("MatchRarityCap") == PvPRules.UltraRare,
	"Ranked isn't even stats with rarity capped"
)
check(
	info.Rules and info.Rules.Stats == "Even" and string.find(info.Rules.Label, "RARITY CAPPED", 1, true),
	"Ranked rules not shown"
)
check(
	not handlers.DuelQueue(ana, "1v1").Ok and not handlers.DuelChallenge(ana, ben.UserId).Ok,
	"Queued or challenged mid-duel"
)
advance(Matchmaking.Countdown)
check(match.State == "Fight" and last(ana, "Fight") ~= nil, "Countdown never ended")
kill(ben)
check(match.State == "Done", "A knockout didn't end the match")
local won, lost = last(ana, "MatchEnd")[2], last(ben, "MatchEnd")[2]
check(won.Won and not lost.Won and won.Delta == 16 and lost.Delta == -16, "Rating change wrong")
check(
	profiles[ana].Duel.Rating == 1016 and profiles[ana].Duel.Wins == 1 and profiles[ben].Duel.Losses == 1,
	"Record not saved"
)
check(
	profiles[ana].Coins == PvPRules.Kinds.Ranked.Rewards.Win
		and profiles[ben].Coins == PvPRules.Kinds.Ranked.Rewards.Loss,
	"Rewards wrong"
)
check(xp[ana] == "DuelWin" and xp[ben] == "DuelPlay" and Season.XP[xp[ana]] > Season.XP[xp[ben]], "XP wrong")
check(ana:GetAttribute("DuelRating") == 1016, "Public rating not updated")
check(
	last(ana, "Feed") ~= nil and string.find(last(ana, "Feed")[2], "Ana defeated Ben", 1, true),
	"No result in the chat feed"
)
advance(Matchmaking.EndPause)
check(
	Duels.matchOf(ana) == nil and ana:GetAttribute("MatchId") == nil and ana:GetAttribute("CombatSession") == nil,
	"Not released after the match"
)
check(
	ana:GetAttribute("MatchStats") == nil and ana:GetAttribute("MatchRarityCap") == nil,
	"PvP rule kept after the match"
)
check(ana.Humanoid.Health == ana.Humanoid.MaxHealth, "Winner not healed on the way back")
respawn(ben)

-- Cancelling, and a busy player can't queue -----------------------------------
check(handlers.DuelQueue(ana, "1v1").Ok and handlers.DuelCancel(ana).Ok, "Cancel failed")
check(ana:GetAttribute("DuelQueue") == nil and not handlers.DuelCancel(ana).Ok, "Still queued after cancelling")
ana:SetAttribute("Expedition", true)
check(not handlers.DuelQueue(ana, "1v1").Ok, "Queued from an expedition")
ana:SetAttribute("Expedition", nil)

-- Friendly challenge: accepted, then forfeited by leaving the session ---------
check(handlers.DuelChallenge(ana, ben.UserId).Ok and last(ben, "Challenge")[2] == ana.UserId, "Challenge not sent")
check(not handlers.DuelRespond(ben, 999, true).Ok, "Accepted a challenge nobody sent")
check(handlers.DuelRespond(ben, ana.UserId, true).Ok, "Challenge not accepted")
match = Duels.matchOf(ben)
check(match and not match.Ranked, "A challenge started a ranked match")
-- No choice given: even stats, no rarity cap; the small challenge reward.
check(
	last(ben, "Challenge")[5] == "Even"
		and ben:GetAttribute("MatchStats") == "Even"
		and ben:GetAttribute("MatchRarityCap") == nil,
	"A plain challenge wasn't even stats"
)
advance(Matchmaking.Countdown)
ben:SetAttribute("CombatSession", nil) -- the Leave button
check(
	match.State == "Done" and last(ana, "MatchEnd")[2].Won and last(ana, "MatchEnd")[2].Reason == "Left",
	"Leaving didn't forfeit"
)
check(last(ana, "MatchEnd")[2].Delta == 0 and profiles[ana].Duel.Rating == 1016, "A friendly duel changed the rating")
advance(Matchmaking.EndPause)
-- An expired challenge can't be accepted.
check(handlers.DuelChallenge(ana, ben.UserId).Ok, "Second challenge refused")
advance(Matchmaking.ChallengeSeconds + 1)
check(not handlers.DuelRespond(ben, ana.UserId, true).Ok, "Accepted an expired challenge")

-- Time limit: the healthier side wins (a full-progression challenge) -----------
local coinsBefore = profiles[ben].Coins
check(
	handlers.DuelChallenge(ana, ben.UserId, "Full").Ok and last(ben, "Challenge")[5] == "Full",
	"Full challenge not offered"
)
check(handlers.DuelRespond(ben, ana.UserId, true).Ok, "Third duel")
match = Duels.matchOf(ana)
check(
	ana:GetAttribute("MatchStats") == "Full" and last(ana, "Match")[2].Rules.Label == "FULL PROGRESSION",
	"Full progression not applied"
)
advance(Matchmaking.Countdown)
ana.Humanoid.Health = 100
advance(Matchmaking.TimeLimit)
check(
	match.State == "Done" and last(ben, "MatchEnd")[2].Won and last(ben, "MatchEnd")[2].Reason == "Time",
	"Time limit winner wrong"
)
check(profiles[ben].Coins - coinsBefore == PvPRules.Kinds.Challenge.Rewards.Win, "Challenge reward wrong")
advance(Matchmaking.EndPause)

-- 2v2: a party of two queues together; only its leader can queue it -----------
local cy, di = makePlayer(3, "Cy"), makePlayer(4, "Di")
local partyAB = { Leader = ana, Members = { ana, ben } }
local partyCD = { Leader = cy, Members = { cy, di } }
parties[ana], parties[ben], parties[cy], parties[di] = partyAB, partyAB, partyCD, partyCD
check(not handlers.DuelQueue(ben, "2v2").Ok, "A party member who isn't leader queued the party")
check(handlers.DuelQueue(ana, "1v1").Ok, "Solo queue refused while in a party")
handlers.DuelCancel(ana)
check(handlers.DuelQueue(ana, "2v2").Ok and ben:GetAttribute("DuelQueue") == "2v2", "Party not queued together")
check(handlers.DuelQueue(cy, "2v2").Ok, "Second party not queued")
advance(0.25)
match = Duels.matchOf(ana)
check(match and match.Mode == "2v2" and Duels.matchOf(di) == match and #match.Teams[1] == 2, "2v2 didn't start")
advance(Matchmaking.Countdown)
kill(cy)
check(match.State == "Fight", "One teammate down ended a 2v2")
kill(di)
check(match.State == "Done" and last(ben, "MatchEnd")[2].Won, "2v2 winner wrong")
advance(Matchmaking.EndPause)
respawn(cy, di)
-- A party that changes shape leaves the queue.
check(handlers.DuelQueue(ana, "2v2").Ok, "Party requeue refused")
parties[ben] = nil
partyAB.Members = { ana }
advance(0.25)
check(ana:GetAttribute("DuelQueue") == nil, "A broken party stayed queued")

-- Casual: matched like Ranked, but unrated, even stats and no rarity cap -------
local eve, fay = makePlayer(5, "Eve"), makePlayer(6, "Fay")
check(handlers.DuelQueue(eve, "casual").Ok and handlers.DuelQueue(fay, "casual").Ok, "Casual queue refused")
advance(0.25)
match = Duels.matchOf(eve)
check(match and match == Duels.matchOf(fay) and not match.Ranked, "Casual didn't start an unrated match")
check(
	eve:GetAttribute("MatchStats") == "Even" and eve:GetAttribute("MatchRarityCap") == nil,
	"Casual isn't even stats without a cap"
)
local eveCoins, fayCoins = profiles[eve].Coins, profiles[fay].Coins
advance(Matchmaking.Countdown)
kill(fay)
check(
	last(eve, "MatchEnd")[2].Delta == 0 and profiles[eve].Duel.Rating == Matchmaking.StartRating,
	"Casual changed a rating"
)
check(
	profiles[eve].Coins - eveCoins == PvPRules.Kinds.Casual.Rewards.Win
		and profiles[fay].Coins - fayCoins == PvPRules.Kinds.Casual.Rewards.Loss,
	"Casual rewards wrong"
)
advance(Matchmaking.EndPause)
respawn(fay)

-- The rules themselves: profiles, labels and the rarity cap --------------------
check(
	PvPRules.profile("Challenge", "Full").Stats == "Full" and PvPRules.profile("Challenge").Stats == "Even",
	"Challenge stats choice"
)
check(PvPRules.profile("Casual", "Full").Stats == "Even", "Casual let full progression in")
check(PvPRules.label(PvPRules.profile("Casual")) == "EVEN STATS", "Casual label")
do
	local roll5 = { Rarity = 5, Stats = { Health = 20, Power = 10 } }
	local roll3 = { Rarity = 3, Stats = { Health = 9 } }
	local loadout = { Armor = "a", GearRolls = { Armors = { a = roll5, b = roll3 } } }
	local capped = PvPRules.capLoadout(loadout, PvPRules.UltraRare)
	local a = capped.GearRolls.Armors.a
	check(a.Rarity == 4 and a.Stats.Health == 16 and a.Stats.Power == 8, "A Legendary roll wasn't scaled to Ultra Rare")
	check(capped.GearRolls.Armors.b == roll3, "A roll under the cap was changed")
	check(
		roll5.Rarity == 5 and roll5.Stats.Health == 20 and loadout.GearRolls.Armors.a == roll5,
		"Capping changed the saved loadout"
	)
	check(PvPRules.capLoadout(loadout, nil) == loadout, "No cap still copied the loadout")
end

-- 1v1 Ranked rounds: first to two, a pivot window between rounds --------------
check(Matchmaking.playsRounds("1v1", "Ranked"), "1v1 Ranked doesn't play rounds")
check(not Matchmaking.playsRounds("1v1", "Challenge"), "An Outpost challenge plays rounds")
check(Matchmaking.playsRounds("casual", "Casual") and not Matchmaking.playsRounds("2v2", "Ranked"), "Rounds leak")
check(Matchmaking.roundsOver({ 1, 0 }, 1) == nil, "One round decided the match")
check(Matchmaking.roundsOver({ 2, 0 }, 2) == 1 and Matchmaking.roundsOver({ 1, 2 }, 3) == 2, "First to two")
check(Matchmaking.roundsOver({ 1, 1 }, 3) == "Draw", "Even after three rounds isn't a draw")
check(Matchmaking.roundsOver({ 1, 0 }, 3) == 1, "Three rounds max")
check(Matchmaking.roundsOver({ 1, 0 }, 2) == nil, "A drawn round ended a catchable match")
do
	local gus, hal = makePlayer(60, "Gus"), makePlayer(61, "Hal")
	profiles[gus].Character = { WeaponGem = { Element = "Fire" } }
	profiles[hal].Character = { ArmorGem = { Element = "Shock" } }
	profiles[gus].Presets =
		{ Weapon = { [2] = { Name = "Frost Kit", Element = "Frost" } }, Armor = { [1] = { Name = "Plate" } } }
	handlers.DuelQueue(gus, "1v1")
	handlers.DuelQueue(hal, "1v1")
	advance(0.25)
	local m = Duels.matchOf(gus)
	check(m and m.Rounds and last(gus, "Match")[2].Rounds.ToWin == 2, "1v1 Ranked started without rounds")
	check(
		last(gus, "Match")[2].Ends - last(gus, "Match")[2].StartsAt == Matchmaking.Rounds.Time,
		"A round isn't Rounds.Time long"
	)
	check(next(m.Shields) ~= nil, "Fighters aren't shielded in the countdown")
	check(handlers.DuelPivot(gus, nil, 2).Ok == false, "A preset switched mid-countdown")
	advance(Matchmaking.Countdown)
	check(m.State == "Fight" and next(m.Shields) == nil, "Shields stayed up into the fight")
	-- Round 1: Hal takes a lethal blow and is downed, not killed.
	lethalBlow(hal)
	check(hal.Humanoid.Health == 1 and m.State == "Pivot", "A lethal blow killed instead of ending the round")
	local pivot = last(gus, "Round")[2]
	check(pivot.Phase == "Pivot" and pivot.Winner == "You" and pivot.Wins.Mine == 1, "Round 1 not Gus's")
	check(last(hal, "Round")[2].Winner == "Them", "Hal wasn't told he lost the round")
	check(table.find(last(hal, "Round")[2].Scout, "Fire") and #last(hal, "Round")[2].Scout == 1, "Hal can't scout Fire")
	check(table.find(pivot.Scout, "Shock"), "Gus can't scout Shock")
	check(next(m.Shields) ~= nil, "Nobody is shielded in the pivot")
	-- Between rounds nothing lands.
	lethalBlow(gus)
	check(gus.Humanoid.Health > 1 and m.State == "Pivot", "A blow landed in the pivot window")
	-- Only the loser may counter-pick a whole miner; selection is hidden until reveal.
	check(not handlers.DuelPivot(gus, 2).Ok, "Round winner changed miners")
	check(not handlers.DuelPivot(hal, 4).Ok, "An invalid miner was accepted")
	check(handlers.DuelPivot(gus, 1).Ok and m.State == "Pivot", "Winner's ready ended the window early")
	check(not handlers.DuelPivot(gus, nil).Ok, "A locked pick changed")
	check(profiles[hal].Miners.Active == 1, "Loser's pick applied before reveal")
	check(handlers.DuelPivot(hal, 2).Ok, "Loser couldn't counter-pick")
	local revealed = last(hal, "Round")[2]
	check(m.State == "Countdown" and revealed.Phase == "Reveal" and revealed.Round == 2, "No reveal after both locked")
	check(profiles[hal].Miners.Active == 2 and profiles[gus].Miners.Active == 1, "Whole miner counter-pick failed")
	check(revealed.Picks.Mine[1].Preset == "Miner 2" and revealed.Picks.Theirs[1].Preset == "Miner 1", "Wrong miners revealed")
	check(hal.Humanoid.Health == hal.Humanoid.MaxHealth, "Hal wasn't healed for round 2")
	-- Round 2 times out even: a drawn round. Round 3: Hal wins it 1-1... then
	-- the match is level after three rounds, a draw.
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	check(m.State == "Fight", "Round 2 didn't start")
	advance(Matchmaking.Rounds.Time)
	check(m.State == "Pivot" and m.Rounds.Played == 2, "Round 2's time didn't end it")
	check(last(gus, "Round")[2].Winner == "Draw", "Even health at time isn't a drawn round")
	check(table.find(last(gus, "Round")[2].Scout, "Frost"), "Scouting did not update to the counter-picked miner")
	-- Nobody locks: the window closes on its own.
	advance(Matchmaking.Rounds.Pivot)
	check(m.State == "Countdown", "The pivot window never closed")
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	local ratingBefore = profiles[hal].Duel.Rating
	lethalBlow(gus)
	check(m.State == "Done", "Three rounds didn't end the match")
	local ended = last(hal, "MatchEnd")[2]
	check(ended.Draw and ended.Rounds.Mine == 1 and ended.Rounds.Theirs == 1, "1-1 after three rounds isn't a draw")
	check(profiles[hal].Duel.Rating == ratingBefore, "A drawn match moved the rating")
	advance(Matchmaking.EndPause)
	check(not Duels.matchOf(gus) and not next(m.Shields), "Shields left after the match")
	respawn(gus, hal)
	-- A clean 2-0, and a forfeit in the pivot window.
	handlers.DuelQueue(gus, "1v1")
	handlers.DuelQueue(hal, "1v1")
	advance(0.25)
	m = Duels.matchOf(gus)
	advance(Matchmaking.Countdown)
	lethalBlow(hal)
	handlers.DuelPivot(gus, nil)
	handlers.DuelPivot(hal, nil)
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(hal)
	ended = last(gus, "MatchEnd")[2]
	check(m.State == "Done" and ended.Won and ended.Rounds.Mine == 2 and ended.Rounds.Theirs == 0, "2-0 not a win")
	check(ended.Delta > 0, "A ranked round win wasn't rated")
	advance(Matchmaking.EndPause)
	respawn(gus, hal)
	handlers.DuelQueue(gus, "1v1")
	handlers.DuelQueue(hal, "1v1")
	advance(0.25)
	m = Duels.matchOf(gus)
	advance(Matchmaking.Countdown)
	lethalBlow(gus)
	check(handlers.DuelLeave(gus).Ok and m.State == "Done" and last(hal, "MatchEnd")[2].Won, "Pivot forfeit")
	advance(Matchmaking.EndPause)
	respawn(gus, hal)
	-- Outpost challenges don't play rounds: a lethal blow is a knockout.
	handlers.DuelChallenge(gus, hal.UserId, "Even")
	handlers.DuelRespond(hal, gus.UserId, true)
	m = Duels.matchOf(gus)
	advance(Matchmaking.Countdown)
	lethalBlow(hal)
	check(m.Rounds == nil and m.State == "Done", "A challenge played rounds")
	advance(Matchmaking.EndPause)
	respawn(gus, hal)
end

-- Lanes: more duels than lanes wait for a free one -----------------------------
local extra = {}
for i = 1, 10 do
	extra[i] = makePlayer(100 + i, "P" .. i)
	check(handlers.DuelQueue(extra[i], "1v1").Ok, "Queue " .. i)
end
advance(0.25)
local running = 0
for i = 1, 10 do
	if Duels.matchOf(extra[i]) then
		running += 1
	end
end
check(running == 2 * Matchmaking.Lanes, "Lanes not limiting duels")
-- Leaving the game forfeits and frees the lane.
local gone = extra[1]
local rival = Duels.matchOf(gone)
Players.PlayerRemoving.Fire(gone)
check(rival.State == "Done", "Leaving the game didn't forfeit")
advance(Matchmaking.EndPause)
advance(0.25)
running = 0
for i = 2, 10 do
	if Duels.matchOf(extra[i]) then
		running += 1
	end
end
check(running == 2 * Matchmaking.Lanes, "A freed lane wasn't reused")

print(
	"PASS: "
		.. checks
		.. " duel checks (Elo, pairing, lanes, who can hit whom, queue, challenges, 2v2 parties, knockouts, forfeits, time limit, rewards)"
)

local playedTasks,wonTasks=0,0
for _,events in taskEvents do playedTasks+=events.PvPPlayed or 0;wonTasks+=events.PvPWin or 0 end
assert(playedTasks>0 and wonTasks>0,"Finished 1v1 matches must emit task events")
print("PASS: real PvP completion emits participation and victory task events")
