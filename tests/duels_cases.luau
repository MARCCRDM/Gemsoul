local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

Duels.start()

-- MATCH READY (Systems/Duels' ready check): everyone the queue has asked
-- says JOIN, so the match can start.
local joined = {}
local function joinAll()
	for _, p in table.clone(playerList) do
		local asked = last(p, "MatchReady")
		local key = asked and (asked[2].Id .. ":" .. p.UserId)
		if key and not joined[key] then
			joined[key] = true
			handlers.DuelReady(p, asked[2].Id, true)
		end
	end
end

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
-- Paired: nobody's put in a match yet; both are asked MATCH READY.
check(Duels.matchOf(ana) == nil and Duels.matchOf(ben) == nil, "The queue started a match nobody had joined")
local asked = last(ana, "MatchReady") and last(ana, "MatchReady")[2]
check(asked and asked.Mode == "1v1" and asked.Seconds == Matchmaking.ReadySeconds and asked.Of == 2, "Ana wasn't asked MATCH READY")
check(#asked.Foes == 1 and asked.Foes[1].Name == "Ben" and not asked.Accepted, "Ana's MATCH READY doesn't name Ben")
check(last(ben, "MatchReady") and last(ben, "MatchReady")[2].Id == asked.Id, "Ben wasn't asked the same MATCH READY")
check(ana:GetAttribute("DuelQueue") == "1v1", "Ana left the queue while being asked")
check(not handlers.DuelReady(ana, "R999", true).Ok, "A made-up ready check was answered")
check(handlers.DuelReady(ben, asked.Id, true).Ok and Duels.matchOf(ben) == nil, "One JOIN started the match")
check(last(ana, "MatchReadyState")[2].Ready == 1, "Ana wasn't told Ben joined")
advance(0.25)
check(Duels.matchOf(ana) == nil, "The match started without Ana")
check(handlers.DuelReady(ana, asked.Id, true).Ok, "Ana couldn't JOIN")
check(last(ana, "MatchReadyOver")[2].Reason == "Started", "The window wasn't closed as started")
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
levelOf[ben] = 7 -- (Ben's a few levels over Ana)
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
-- Your level's XP goes by the other side's level (Shared.Levelling: more
-- for beating a higher one), the Season Path's by the result, and the one
-- beaten is named (beaten again soon, worth less).
check(
	xpFoe[ana].Level == 7 and xpFoe[ana].Season == "DuelWin" and xpFoe[ana].Rival == ben,
	"A duel won doesn't go by the loser's level"
)
check(xpFoe[ben].Level == 1 and xpFoe[ben].Season == "DuelPlay" and xpFoe[ben].Rival == ana, "A duel lost doesn't go by the winner's level")
levelOf[ben] = nil
-- The arena tournament (Shared.SwingRestore): the first win of a run
-- restores 10% of the pick's swings; the loss ends the loser's run.
check(
	won.Tournament
		and won.Tournament.Win == 1
		and won.Tournament.Counted
		and won.Tournament.Share == SwingRestore.Streak[1]
		and won.Tournament.Swings == 60
		and won.Tournament.NextAt == 5,
	"A queued ranked win didn't restore the first tournament share"
)
check(
	lost.Tournament and lost.Tournament.Win == 0 and lost.Tournament.Swings == 0 and lost.Tournament.NextShare == SwingRestore.Streak[1],
	"A loss's tournament line"
)
check(#restoresGiven == 1 and restoresGiven[1].Player == ana and restoresGiven[1].Share == SwingRestore.Streak[1], "Restores given")
-- Rewards (Shared.RewardRoll): both played one more 1v1; the winner's win
-- reward (two pieces, keep one) over the one beaten, and said with the result.
check(
	RewardRoll.plays(profiles[ana].Duel) >= 1 and RewardRoll.plays(profiles[ben].Duel) >= 1,
	"A 1v1 played didn't count toward the rewards' ladder"
)
check(#winRewards == 1 and winRewards[1].Player == ana and winRewards[1].Foe == ben.UserId, "The winner got no win reward")
check(won.WinReward == true and lost.WinReward == false and won.Plays == RewardRoll.plays(profiles[ana].Duel), "The result doesn't say the win reward")
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
check(last(ana, "MatchEnd")[2].Tournament == nil and #restoresGiven == 1, "A challenge counted toward the tournament")
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
check(last(di, "MatchReady") and #last(di, "MatchReady")[2].Foes == 2, "A party member wasn't asked, or the other party isn't named")
joinAll()
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
joinAll()
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
-- Casual's own run: the first win restores swings too.
check(
	last(eve, "MatchEnd")[2].Tournament.Win == 1
		and profiles[eve].Duel.CasualStreak == 1
		and last(fay, "MatchEnd")[2].Tournament.Win == 0,
	"Casual's tournament run"
)
advance(Matchmaking.EndPause)
respawn(fay)
-- Beating the same player again doesn't add to the run.
check(handlers.DuelQueue(eve, "casual").Ok and handlers.DuelQueue(fay, "casual").Ok, "Casual rematch refused")
advance(0.25)
joinAll()
advance(Matchmaking.Countdown)
kill(fay)
check(
	not last(eve, "MatchEnd")[2].Tournament.Counted and profiles[eve].Duel.CasualStreak == 1,
	"The same opponent twice running counted"
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
	joinAll()
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
	table.clear(preparedDrops)
	check(handlers.DuelPivot(hal, 2).Ok, "Loser couldn't counter-pick")
	local revealed = last(hal, "Round")[2]
	check(m.State == "Countdown" and revealed.Phase == "Reveal" and revealed.Round == 2, "No reveal after both locked")
	check(profiles[hal].Miners.Active == 2 and profiles[gus].Miners.Active == 1, "Whole miner counter-pick failed")
	check(revealed.Picks.Mine[1].Preset == "Miner 2" and revealed.Picks.Theirs[1].Preset == "Miner 1", "Wrong miners revealed")
	check(hal.Humanoid.Health == hal.Humanoid.MaxHealth, "Hal wasn't healed for round 2")
	-- Round 2 starts like round 1: both back in their pods while the picks
	-- show, then dropped onto the lanes.
	check(preparedDrops[gus] and preparedDrops[hal], "Round 2 didn't put them back in the pods")
	local beganBefore = #dropBegins
	advance(Matchmaking.Rounds.Reveal)
	check(#dropBegins == beganBefore + 1, "Round 2 didn't drop them from the pods")
	local dropped = dropBegins[#dropBegins]
	check(
		table.find(dropped, gus.Character) and table.find(dropped, hal.Character),
		"Round 2's drop left a fighter in the pod"
	)
	check(m.State == "Countdown", "Round 2 started before the drop landed")
	-- Round 2 times out even: a drawn round. Round 3: Hal wins it 1-1... then
	-- the match is level after three rounds, a draw.
	advance(Matchmaking.Countdown)
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
	joinAll()
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
	joinAll()
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
	-- One miner (Config.Features.MinerRoster off): the window between rounds
	-- is a short break with nobody to pick, and nobody swaps, loser included.
	MinerRoster.configure(false)
	handlers.DuelQueue(gus, "1v1")
	handlers.DuelQueue(hal, "1v1")
	advance(0.25)
	joinAll()
	m = Duels.matchOf(gus)
	advance(Matchmaking.Countdown)
	lethalBlow(gus)
	pivot = last(gus, "Round")[2]
	check(m.State == "Pivot" and pivot.Ends - now <= Matchmaking.Rounds.Break, "One miner still got the long pick")
	check(not pivot.CanSwap and not last(hal, "Round")[2].CanSwap, "A counter-pick was offered with one miner")
	local active = profiles[gus].Miners.Active
	check(not handlers.DuelPivot(gus, active % 3 + 1).Ok, "The loser swapped in another miner")
	check(handlers.DuelPivot(gus, nil).Ok and handlers.DuelPivot(hal, nil).Ok, "READY failed with one miner")
	revealed = last(gus, "Round")[2]
	check(revealed.Phase == "Reveal" and revealed.Picks.Mine[1].Preset == nil, "A miner number was revealed")
	check(profiles[gus].Miners.Active == active, "The active miner changed")
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(hal)
	check(m.State == "Pivot", "Round 2 didn't end on a knockout")
	advance(Matchmaking.Rounds.Break)
	check(m.State == "Countdown", "The one-miner break never closed")
	MinerRoster.configure(true)
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(gus)
	check(m.State == "Done", "Round 3 didn't end the match")
	advance(Matchmaking.EndPause)
	respawn(gus, hal)
	-- COUNTER (Systems/CounterServer): the round's loser may wear the armor
	-- answer to what hurt them; the winner keeps their gear. One miner here
	-- (the beta), so the counter is the only pick.
	MinerRoster.configure(false)
	profiles[hal].Counter = {
		Element = "Fire",
		Changes = 2,
		Gems = { { Slot = "Helmet", Gem = "g1", Element = "Fire" }, { Slot = "Boots", Gem = "g2", Element = "Fire" } },
		Gear = {},
		Lines = { { Element = "Fire", Share = 1, Before = 1.25, After = 0.84 } },
		Before = 1.25,
		After = 0.84,
	}
	profiles[gus].Counter = { Element = "Shock", Changes = 1, Gems = {}, Gear = {}, Lines = {} }
	handlers.DuelQueue(gus, "1v1")
	handlers.DuelQueue(hal, "1v1")
	advance(0.25)
	joinAll()
	m = Duels.matchOf(gus)
	check((counterRounds[hal] or 0) > 0, "A match began with last match's damage on the books")
	advance(Matchmaking.Countdown)
	lethalBlow(hal)
	local lost, won = last(hal, "Round")[2], last(gus, "Round")[2]
	check(lost.CanCounter and lost.Counter and lost.Counter.Element == "Fire", "The round's loser wasn't offered the counter")
	check(lost.Threat and lost.Threat.Shares[1].Element == "Fire", "The loser wasn't told what hurt them")
	check(not won.CanCounter and won.Counter == nil, "The round's winner was offered a counter")
	check(lost.Ends - now > Matchmaking.Rounds.Break, "A counter to pick still got the short break")
	check(not handlers.DuelPivot(gus, "Counter").Ok, "The round's winner countered")
	-- Marking it (hold) doesn't lock; the window closing wears what's marked.
	check(handlers.DuelPivot(hal, "Counter", true).Ok and not m.Rounds.Locked[hal], "Marking the counter locked it")
	check(handlers.DuelPivot(hal, "Keep", true).Ok and m.Rounds.Picks[hal] == nil, "Going back to KEEP didn't clear it")
	check(handlers.DuelPivot(hal, "Counter", true).Ok, "The counter couldn't be marked again")
	check(not counterWorn[hal], "The counter was worn before the reveal")
	advance(Matchmaking.Rounds.Pivot)
	check(m.State == "Countdown" and counterWorn[hal] == 1 and not counterWorn[gus], "The marked counter wasn't worn at the reveal")
	local shown = last(gus, "Round")[2]
	check(shown.Phase == "Reveal" and shown.Picks.Theirs[1].Countered == "Fire", "The winner wasn't shown the counter")
	check(last(hal, "Round")[2].Picks.Mine[1].Countered == "Fire", "The loser wasn't shown their counter")
	-- Round 2 to Hal: now Gus may counter, Hal keeps.
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(gus)
	check(last(gus, "Round")[2].CanCounter and not last(hal, "Round")[2].CanCounter, "The counter didn't pass to round 2's loser")
	check(handlers.DuelPivot(gus, "Counter").Ok and handlers.DuelPivot(hal, nil).Ok, "Locking in failed")
	check(counterWorn[gus] == 1 and counterWorn[hal] == 1, "Round 2's counter wasn't worn (or the winner's was)")
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(hal)
	check(m.State == "Done", "Round 3 didn't end the match")
	profiles[hal].Counter, profiles[gus].Counter = nil, nil
	MinerRoster.configure(true)
	advance(Matchmaking.EndPause)
	respawn(gus, hal)
end

-- MATCH READY: a decline or no answer leaves the queue; the other side
-- keeps searching, its place kept ------------------------------------------------
do
	local rae, sol, tia = makePlayer(70, "Rae"), makePlayer(71, "Sol"), makePlayer(72, "Tia")
	handlers.DuelQueue(rae, "casual")
	handlers.DuelQueue(sol, "casual")
	advance(0.25)
	local id = last(rae, "MatchReady")[2].Id
	check(handlers.DuelReady(rae, id, true).Ok, "Rae couldn't join")
	check(handlers.DuelReady(sol, id, false).Ok, "Sol couldn't decline")
	check(sol:GetAttribute("DuelQueue") == nil and Duels.matchOf(sol) == nil, "Declining kept Sol queued")
	check(rae:GetAttribute("DuelQueue") == "casual" and Duels.matchOf(rae) == nil, "Rae wasn't put back to searching")
	local over = last(rae, "MatchReadyOver")[2]
	check(over.Id == id and over.Reason == "Declined" and over.Searching, "Rae's window didn't close as declined, still searching")
	check(last(sol, "MatchReadyOver")[2].Searching == false, "Sol's window says he's still searching")
	check(not handlers.DuelReady(sol, id, true).Ok, "A declined match could still be joined")
	-- Rae kept her place: the next one queued is paired with her.
	handlers.DuelQueue(tia, "casual")
	advance(0.25)
	id = last(tia, "MatchReady")[2].Id
	check(last(rae, "MatchReady")[2].Id == id, "Rae wasn't paired with the next one queued")
	-- Rae doesn't answer this time: past ReadySeconds she leaves the queue.
	check(handlers.DuelReady(tia, id, true).Ok, "Tia couldn't join")
	advance(Matchmaking.ReadySeconds + 0.25)
	check(
		rae:GetAttribute("DuelQueue") == nil and last(rae, "MatchReadyOver")[2].Reason == "Expired",
		"Rae, who never answered, stayed queued"
	)
	check(tia:GetAttribute("DuelQueue") == "casual" and Duels.matchOf(tia) == nil, "Tia, who joined, wasn't kept searching")
	-- Cancelling while asked: the other side keeps searching.
	handlers.DuelQueue(sol, "casual")
	advance(0.25)
	id = last(sol, "MatchReady")[2].Id
	handlers.DuelCancel(sol)
	advance(0.25)
	check(
		last(tia, "MatchReadyOver")[2].Id == id and tia:GetAttribute("DuelQueue") == "casual",
		"Cancelling didn't hand Tia back to the queue"
	)
	handlers.DuelCancel(tia)
end

-- Lanes: more duels than lanes wait for a free one -----------------------------
local extra = {}
for i = 1, 10 do
	extra[i] = makePlayer(100 + i, "P" .. i)
	check(handlers.DuelQueue(extra[i], "1v1").Ok, "Queue " .. i)
end
advance(0.25)
joinAll()
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
joinAll()
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

-- Auto queue (Shared.AutoQueue): the lobby is on call -----------------------------
do
	local before = checks
	-- The shared rules.
	local function attrs(t)
		return function(name)
			return t[name]
		end
	end
	check(AutoQueue.ready(attrs({ Outpost = true })), "A free lobby player isn't ready")
	check(not AutoQueue.ready(attrs({})), "Someone outside the lobby was ready")
	check(not AutoQueue.ready(attrs({ Outpost = true }), true), "A player already searching was ready")
	for _, name in { "CombatSession", "MatchId", "KaijuBattle", "Spar", "MechPilot", "DungeonQueue", "FirstFight", "RiftRun" } do
		local ok, why = AutoQueue.ready(attrs({ Outpost = true, [name] = true }))
		check(not ok and type(why) == "string", name .. " didn't make a player unready")
	end
	check(AutoQueue.setting(nil) == true and AutoQueue.setting({}) == true, "Auto queue isn't on by default")
	check(AutoQueue.setting({ AutoQueue = false }) == false, "Switching auto queue off didn't stick")
	check(
		AutoQueue.introPhase(0) == "Search"
			and AutoQueue.introPhase(AutoQueue.Intro.CallAfter) == "Call"
			and AutoQueue.introPhase(AutoQueue.Intro.BotAfter) == "Bot",
		"Intro phases"
	)
	check(AutoQueue.Intro.CallAfter < AutoQueue.Intro.BotAfter, "The bot comes before the lobby is called")
	local picked = AutoQueue.pick({ { Rating = 1300, Name = "a" }, { Rating = 1040, Name = "b" }, { Rating = 900, Name = "c" } }, 1000)
	check(picked and picked.Name == "b", "The closest rating wasn't picked")
	check(AutoQueue.pick({}, 1000) == nil, "An empty lobby picked someone")
	check(AutoQueue.bonus(true, true) == AutoQueue.FillBonus and AutoQueue.bonus(true, false) == 0 and AutoQueue.bonus(false, true) == 0, "Fill bonus")
	check(Matchmaking.Modes.intro and Matchmaking.Modes.intro.Intro and PvPRules.Kinds.FirstFight, "The intro mode and its rule are missing")
	check(not Matchmaking.playsRounds("intro", "FirstFight"), "A first fight plays rounds")

	-- Clear the decks: the lane test above left duels running and players
	-- queued (a lobby player would be called into those).
	for _, p in table.clone(playerList) do
		if Duels.matchOf(p) or p:GetAttribute("DuelQueue") then
			Players.PlayerRemoving.Fire(p)
			local i = table.find(playerList, p)
			if i then
				table.remove(playerList, i)
			end
		end
	end
	advance(Matchmaking.EndPause + 0.25)
	-- Every finished match so far has left everyone out of the lobby; put the
	-- cast in the Outpost as veterans with a duel behind them.
	local function lobby(p, played)
		p:SetAttribute("Outpost", true)
		local record = Duels.record(p)
		record.Played = played or record.Played or 1
		p:SetAttribute("DuelsPlayed", record.Played)
	end
	local ivy, jon, kim = makePlayer(31, "Ivy"), makePlayer(32, "Jon"), makePlayer(33, "Kim")
	lobby(jon, 4)
	lobby(kim, 4)
	Duels.record(jon).Rating = 1300
	Duels.record(kim).Rating = 1020
	-- (The watch loop publishes; and they've been in the lobby a while, past
	-- the moment after logging in: AutoQueue.Settle.)
	advance(AutoQueue.Settle)
	check(jon:GetAttribute("DuelAuto") == true, "Auto queue isn't on by default on the player")

	-- Ivy queues Ranked alone: after CallAfter seconds the closest lobby player is pulled in.
	check(handlers.DuelQueue(ivy, "1v1").Ok, "Ivy not queued")
	advance(AutoQueue.CallAfter - 1)
	check(Duels.matchOf(ivy) == nil, "The lobby was called too soon")
	advance(1.5)
	check(Duels.matchOf(ivy) == nil and Duels.matchOf(kim) == nil, "Saved auto-on setting pulled a player without consent")
	check(handlers.DuelFill(kim, last(kim, "FillIn")[2].Id, true).Ok, "Invitation acceptance failed")
	-- Kim's said yes; Ivy, who was waiting, is asked MATCH READY.
	check(Duels.matchOf(ivy) == nil, "A fill-in started before the one waiting joined")
	local fillAsk = last(ivy, "MatchReady")[2]
	check(fillAsk.Foes[1].Name == "Kim" and fillAsk.Ready == 1 and fillAsk.Of == 2, "Ivy's MATCH READY doesn't show Kim in")
	check(last(kim, "MatchReady")[2].Accepted == true, "Kim was asked again after saying yes")
	joinAll()
	local m = Duels.matchOf(ivy)
	check(m ~= nil and Duels.matchOf(kim) == m and Duels.matchOf(jon) == nil, "The closest-rated lobby player wasn't pulled in")
	check(m.Ranked and m.Called[kim] and not m.Called[ivy], "The pulled player isn't marked as called")
	local info = last(kim, "Match")[2]
	check(info.Called == true and info.Bonus == AutoQueue.FillBonus and info.Mode == "1v1", "Kim's Match payload doesn't say she was called")
	check(last(ivy, "Match")[2].Called == false, "Ivy's Match payload says she was called")
	local note = last(kim, "Notify")
	check(note and string.find(note[2], "Called in", 1, true), "Kim wasn't told she was called")
	-- Kim loses: a called player's rating never drops; Ivy's rises.
	local kimBefore, ivyBefore = Duels.record(kim).Rating, Duels.record(ivy).Rating
	advance(Matchmaking.Countdown)
	lethalBlow(kim)
	advance(Matchmaking.Rounds.Pivot)
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(kim)
	check(m.State == "Done", "The called match didn't finish")
	local kimEnd, ivyEnd = last(kim, "MatchEnd")[2], last(ivy, "MatchEnd")[2]
	check(not kimEnd.Won and kimEnd.Called == true and kimEnd.Bonus == 0 and kimEnd.Delta == 0, "A called loss cost rating or paid a bonus")
	check(Duels.record(kim).Rating == kimBefore and Duels.record(ivy).Rating > ivyBefore, "Ratings after a called loss")
	check(ivyEnd.Won and ivyEnd.Called == false and ivyEnd.Bonus == 0, "The queuer got a fill bonus")
	advance(Matchmaking.EndPause)
	respawn(ivy, kim)

	-- Kim wins the next one she's called into: the mode's win plus the bonus.
	lobby(kim)
	lobby(jon)
	jon:SetAttribute("Outpost", nil) -- (Jon left the lobby)
	local coinsBefore = profiles[kim].Coins
	check(handlers.DuelQueue(ivy, "casual").Ok, "Ivy not queued for Casual")
	advance(AutoQueue.CallAfter + 0.5)
	check(Duels.matchOf(kim) == nil, "Casual match started before acceptance")
	check(handlers.DuelFill(kim, last(kim, "FillIn")[2].Id, true).Ok, "Casual invitation failed")
	joinAll()
	m = Duels.matchOf(ivy)
	check(m and Duels.matchOf(kim) == m and not m.Ranked, "Kim wasn't pulled into the Casual queue")
	advance(Matchmaking.Countdown)
	lethalBlow(ivy)
	advance(Matchmaking.Rounds.Pivot)
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(ivy)
	kimEnd = last(kim, "MatchEnd")[2]
	check(kimEnd.Won and kimEnd.Bonus == AutoQueue.FillBonus, "A called win didn't pay the bonus")
	check(kimEnd.Coins == PvPRules.Kinds.Casual.Rewards.Win + AutoQueue.FillBonus, "Coins don't include the bonus")
	check(profiles[kim].Coins == coinsBefore + kimEnd.Coins, "The bonus wasn't paid out")
	advance(Matchmaking.EndPause)
	respawn(ivy, kim)

	-- Busy lobby players are never pulled.
	lobby(kim)
	for _, name in { "KaijuBattle", "Spar", "MechPilot", "CombatSession" } do
		kim:SetAttribute(name, true)
		check(handlers.DuelQueue(ivy, "casual").Ok, "Ivy not queued")
		advance(AutoQueue.CallAfter + 0.5)
		check(Duels.matchOf(ivy) == nil, "A lobby player with " .. name .. " was pulled in")
		handlers.DuelCancel(ivy)
		kim:SetAttribute(name, nil)
	end
	-- (CombatSession was set by hand above; Kim's back in the lobby.)
	lobby(kim)

	-- Invitations off: neither forced entry nor a popup. On always asks.
	check(handlers.DuelAuto(kim, false).Ok and kim:GetAttribute("DuelAuto") == false, "Auto queue didn't switch off")
	check(profiles[kim].Duel.AutoQueue == false, "The choice isn't saved in the profile")
	local previousOffer = last(kim, "FillIn")
	check(handlers.DuelQueue(ivy, "casual").Ok, "Ivy not queued while invites muted")
	advance(AutoQueue.CallAfter + 0.5)
	check(last(kim, "FillIn") == previousOffer and Duels.matchOf(kim) == nil, "Muted invitations still interrupted player")
	handlers.DuelCancel(ivy)
	check(handlers.DuelAuto(kim, true).Ok, "Could not enable invitations")
	check(handlers.DuelQueue(ivy, "casual").Ok, "Ivy not queued")
	local entryId = nil
	advance(AutoQueue.CallAfter + 0.5)
	check(Duels.matchOf(ivy) == nil and Duels.matchOf(kim) == nil, "A player with auto queue off was pulled in")
	local offer = last(kim, "FillIn")
	check(offer ~= nil, "Kim wasn't offered the fill-in")
	offer = offer[2]
	entryId = offer.Id
	check(offer.Who == "Ivy" and offer.Mode == "casual" and offer.Bonus == AutoQueue.FillBonus and offer.Seconds == AutoQueue.AskSeconds, "The offer's details")
	local offers = 0
	for _, message in sent[kim] do
		if message[1] == "FillIn" then
			offers += 1
		end
	end
	advance(2)
	for _, message in sent[kim] do
		if message[1] == "FillIn" then
			offers -= 1
		end
	end
	check(offers == 0, "Kim was offered the same queue twice")
	check(not handlers.DuelFill(kim, "Q999", true).Ok, "A stale offer was accepted")
	check(not handlers.DuelFill(jon, entryId, true).Ok, "Uninvited player forged an acceptance")
	check(handlers.DuelFill(kim, entryId, false).Ok and Duels.matchOf(kim) == nil, "Declining failed")
	check(not handlers.DuelFill(kim, entryId, true).Ok, "Declined invitation could still be accepted")
	handlers.DuelCancel(ivy)
	check(handlers.DuelQueue(ivy, "casual").Ok, "Requeue after decline failed")
	advance(AutoQueue.CallAfter + 0.5)
	entryId = last(kim, "FillIn")[2].Id
	advance(AutoQueue.AskSeconds + 0.5)
	check(not handlers.DuelFill(kim, entryId, true).Ok and Duels.matchOf(kim) == nil, "Expired invitation started a match")
	handlers.DuelCancel(ivy)
	check(handlers.DuelQueue(ivy, "casual").Ok, "Requeue after expiry failed")
	advance(AutoQueue.CallAfter + 0.5)
	entryId = last(kim, "FillIn")[2].Id
	check(handlers.DuelFill(kim, entryId, true).Ok, "Accepting the fill-in failed")
	joinAll()
	m = Duels.matchOf(ivy)
	check(m and Duels.matchOf(kim) == m and m.Called[kim], "Accepting didn't start the match")
	advance(Matchmaking.Countdown)
	lethalBlow(ivy)
	advance(Matchmaking.Rounds.Pivot)
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(ivy)
	advance(Matchmaking.EndPause)
	respawn(ivy, kim)
	-- Cancelling a queue ends its offers.
	lobby(kim)
	check(handlers.DuelQueue(ivy, "casual").Ok, "Ivy not queued")
	advance(AutoQueue.CallAfter + 0.5)
	offer = last(kim, "FillIn")[2]
	handlers.DuelCancel(ivy)
	local over = last(kim, "FillInOver")
	check(over and over[2] == offer.Id, "The offer wasn't withdrawn when the queue was cancelled")
	check(handlers.DuelAuto(kim, true).Ok and kim:GetAttribute("DuelAuto") == true, "Auto queue didn't switch back on")

	-- Just logged in: a moment first (AutoQueue.Settle). Searching at once,
	-- but no fill-in card and no MATCH READY till it's passed.
	check(
		not AutoQueue.settled(nil, 100) and AutoQueue.settled(0, AutoQueue.Settle) and not AutoQueue.settled(0, AutoQueue.Settle - 1),
		"Settled after logging in"
	)
	check(AutoQueue.holdUntil(5, 7) == 5 + AutoQueue.Settle and AutoQueue.holdUntil(nil, 7) == 7 + AutoQueue.Settle, "An auto search's hold")
	local lia, max = makePlayer(51, "Lia"), makePlayer(52, "Max")
	lobby(lia, 4)
	check(handlers.DuelQueue(ivy, "casual").Ok, "Ivy not queued")
	advance(AutoQueue.CallAfter + 0.5)
	check(last(kim, "FillIn") ~= nil and last(lia, "FillIn") == nil, "A player who'd just logged in was asked to fill in")
	handlers.DuelCancel(ivy)
	lobby(max, 4)
	check(handlers.DuelReturnQueue(lia).Ok and handlers.DuelReturnQueue(max).Ok, "Auto queue on arriving failed")
	check(lia:GetAttribute("DuelQueue") == "1v1" and max:GetAttribute("DuelQueue") == "1v1", "Not searching straight away")
	advance(1)
	check(last(lia, "MatchReady") == nil and last(max, "MatchReady") == nil, "Asked MATCH READY straight after logging in")
	advance(AutoQueue.Settle)
	local liaAsk, maxAsk = last(lia, "MatchReady"), last(max, "MatchReady")
	check(liaAsk and maxAsk and liaAsk[2].Id == maxAsk[2].Id, "Not asked MATCH READY once the moment had passed")
	check(liaAsk[2].Bonus == 0, "A plain pairing carried a bonus")
	handlers.DuelReady(lia, liaAsk[2].Id, false)
	handlers.DuelCancel(max)
	for _, p in { lia, max } do
		Players.PlayerRemoving.Fire(p)
		table.remove(playerList, table.find(playerList, p))
	end

	-- One question at a time: Kim's offered Ivy's queue, then starts her own
	-- search (auto queue). The card comes down, and met with that same
	-- queue, its bonus comes along (MATCH READY says so; she's called in).
	lobby(kim)
	check(handlers.DuelQueue(ivy, "1v1").Ok, "Ivy not queued")
	advance(AutoQueue.CallAfter + 0.5)
	offer = last(kim, "FillIn")[2]
	check(handlers.DuelReturnQueue(kim).Ok, "Kim's own search didn't start")
	over = last(kim, "FillInOver")
	check(over and over[2] == offer.Id, "The fill-in card stayed up once Kim was searching")
	check(not handlers.DuelFill(kim, offer.Id, true).Ok, "The taken-down card could still be accepted")
	advance(0.5)
	local kimAsk = last(kim, "MatchReady")[2]
	check(kimAsk.Bonus == AutoQueue.FillBonus and last(ivy, "MatchReady")[2].Bonus == 0, "The carried bonus isn't on Kim's MATCH READY")
	joinAll()
	m = Duels.matchOf(kim)
	check(m and Duels.matchOf(ivy) == m and m.Called[kim] and not m.Called[ivy], "Kim isn't called in for the carried bonus")
	check(last(kim, "Match")[2].Bonus == AutoQueue.FillBonus, "Kim's Match payload doesn't carry the bonus")
	advance(Matchmaking.Countdown)
	lethalBlow(ivy)
	advance(Matchmaking.Rounds.Pivot)
	advance(Matchmaking.Rounds.Reveal + Matchmaking.Countdown)
	lethalBlow(ivy)
	kimEnd = last(kim, "MatchEnd")[2]
	check(kimEnd.Won and kimEnd.Bonus == AutoQueue.FillBonus, "The carried bonus wasn't paid on the win")
	advance(Matchmaking.EndPause)
	respawn(ivy, kim)

	-- The intro queue: two new players pair at once ---------------------------------
	local new1, new2 = makePlayer(41, "Nia"), makePlayer(42, "Oli")
	check(not handlers.DuelQueue(new1, "intro").Ok, "The PLAY menu could queue the intro")
	check(not handlers.IntroQueue(kim).Ok, "A veteran joined the intro queue")
	check(handlers.IntroQueue(new1).Ok and new1:GetAttribute("DuelQueue") == "intro", "Nia isn't in the intro queue")
	check(last(new1, "Queue")[2].Intro == true, "The intro queue state isn't marked")
	advance(0.25)
	check(Duels.matchOf(new1) == nil, "A lone new player was matched")
	check(handlers.IntroQueue(new2).Ok, "Oli isn't in the intro queue")
	advance(0.25)
	m = Duels.matchOf(new1)
	check(m and Duels.matchOf(new2) == m, "Two new players weren't paired at once")
	check(m.Intro and m.Rules.Kind == "FirstFight" and not m.Ranked and m.Rounds == nil, "A first fight isn't a FirstFight single fight")
	check(new1:GetAttribute("FirstFight") == true and new2:GetAttribute("FirstFight") == true, "First fighters didn't get their hints")
	check(last(new1, "Match")[2].Intro == true, "The Match payload isn't marked as the intro")
	advance(Matchmaking.Countdown)
	lethalBlow(new2)
	check(m.State == "Done", "A first fight didn't end on one knockout")
	check(new1:GetAttribute("FirstFight") == nil and new2:GetAttribute("FirstFight") == nil, "FirstFight wasn't cleared")
	check(new1:GetAttribute("IntroGuide") == true and new2:GetAttribute("IntroGuide") == true, "No arrows through the Outpost after the first fight")
	check(new1:GetAttribute("DuelsPlayed") == 1 and new2:GetAttribute("DuelsPlayed") == 1, "The first fight didn't count as played")
	check(string.find(last(new1, "Notify")[2], "Welcome to the Saga Outpost", 1, true), "The winner wasn't welcomed")
	check(string.find(last(new2, "Notify")[2], "Welcome to the Saga Outpost", 1, true), "The loser wasn't welcomed")
	check(last(new1, "MatchEnd")[2].Intro == true and last(new1, "MatchEnd")[2].Coins == PvPRules.Kinds.FirstFight.Rewards.Win, "A first fight win's pay")
	advance(Matchmaking.EndPause)
	respawn(new1, new2)
	check(not handlers.IntroQueue(new1).Ok, "A player with a fight behind them re-entered the intro queue")
	-- Back in the lobby, the client queues them for a 1v1 Casual (Lobby.client):
	-- the server takes a fresh player straight out of the intro, and sends the
	-- queue state the SEARCHING card shows.
	check(handlers.DuelQueue(new1, "casual").Ok, "A player fresh from the intro couldn't join the Casual queue")
	check(new1:GetAttribute("DuelQueue") == "casual" and last(new1, "Queue")[2].Mode == "casual" and not last(new1, "Queue")[2].Intro, "No Casual queue state after the intro")
	check(handlers.DuelCancel(new1).Ok and new1:GetAttribute("DuelQueue") == nil, "Couldn't leave the Casual queue")

	-- Alone: a lobby player on call is pulled in after Intro.CallAfter -------------
	local new3 = makePlayer(43, "Pax")
	lobby(kim)
	check(handlers.IntroQueue(new3).Ok, "Pax isn't in the intro queue")
	advance(AutoQueue.Intro.CallAfter - 1)
	check(Duels.matchOf(new3) == nil, "The lobby was called into the intro too soon")
	advance(1.5)
	check(Duels.matchOf(new3) == nil and Duels.matchOf(kim) == nil, "New player pulled a veteran without consent")
	local introOffer = last(kim, "FillIn")[2]
	check(introOffer.Intro and introOffer.BonusUpfront and introOffer.Bonus == 20 and introOffer.Seconds <= 10, "Intro invitation does not disclose immediate bonus and actual expiry")
	local beforeJoin = profiles[kim].Coins
	check(handlers.DuelFill(kim, introOffer.Id, true).Ok, "First-fight invitation could not be accepted")
	check(profiles[kim].Coins == beforeJoin + 20, "First-fight join bonus was not paid upfront")
	check(Duels.record(new3).IntroHelpRewarded == true, "First-fight bonus was not marked paid")
	check(not handlers.DuelFill(kim, introOffer.Id, true).Ok and profiles[kim].Coins == beforeJoin + 20, "Duplicate acceptance paid twice")
	m = Duels.matchOf(new3)
	check(m and Duels.matchOf(kim) == m and m.Intro and m.Called[kim], "A lobby player wasn't called into the first fight")
	check(new3:GetAttribute("FirstFight") == true and kim:GetAttribute("FirstFight") == nil, "Only the new player gets the hints")
	advance(Matchmaking.Countdown)
	lethalBlow(new3)
	check(m.State == "Done", "The called first fight didn't end")
	kimEnd = last(kim, "MatchEnd")[2]
	check(kimEnd.Won and kimEnd.Bonus == 0 and kimEnd.JoinBonus == AutoQueue.FillBonus and kimEnd.Intro == true, "The intro bonus was paid again at match end")
	check(profiles[kim].Coins == beforeJoin + 20 + PvPRules.Kinds.FirstFight.Rewards.Win, "Incorrect intro total payout")
	check(new3:GetAttribute("FirstFight") == nil and new3:GetAttribute("DuelsPlayed") == 1, "Pax's first fight didn't count")
	check(new3:GetAttribute("IntroGuide") == true and kim:GetAttribute("IntroGuide") == nil, "Only the new player is walked through the Outpost")
	advance(Matchmaking.EndPause)
	respawn(new3, kim)

	-- Alone with nobody around: the sparring rival after Intro.BotAfter --------------
	local new4 = makePlayer(44, "Quin")
	lobby(kim)
	check(handlers.IntroQueue(new4).Ok, "Quin isn't in the intro queue")
	advance(AutoQueue.Intro.BotAfter - 1)
	check(new4:GetAttribute("DuelQueue") == "intro" and #trainingEntered == 0, "The rival came too soon")
	check(Duels.matchOf(kim) == nil, "Ignoring invitation pulled the lobby player")
	advance(1.5)
	check(#trainingEntered == 1 and trainingEntered[1] == new4, "The sparring rival didn't step in")
	check(new4:GetAttribute("DuelQueue") == nil and Duels.matchOf(new4) == nil, "Quin is still queued")
	check(string.find(last(new4, "Notify")[2], "sparring partner", 1, true), "Quin wasn't told about the rival")
	new4:SetAttribute("CombatSession", nil)

	-- Nobody is called while the Arena's lanes are full: the entry waits.
	print("PASS: " .. (checks - before) .. " lobby invitation checks (explicit consent, muted invites, expiry, decline, forged requests, a moment after logging in, one card at a time, the bonus carried over, upfront intro bonus, no duplicate payment, normal PvP rewards unchanged, bot fallback)")
end

-- Auto queue: back in the lobby (from a dungeon or the Rift, or arriving),
-- you're searching ranked 1v1 without being asked. Two searching are
-- paired, but nobody's put in the match until they say JOIN (MATCH READY).
-- Off, no search; switched off while searching, out of the queue.
do
	local a, b = makePlayer(81, "ReturnWin"), makePlayer(82, "ReturnLoss")
	for _, p in { a, b } do
		p:SetAttribute("Outpost", true)
	end
	advance(AutoQueue.Settle) -- (they logged in a while ago)
	for _, p in { a, b } do
		p:SetAttribute("DungeonId", "test-run")
		check(not handlers.DuelReturnQueue(p).Ok, "Auto queued inside dungeon")
		check(not handlers.DuelQueue(p, "1v1").Ok, "Manual queue allowed inside dungeon")
		p:SetAttribute("DungeonId", nil)
		check(p:GetAttribute("DuelQueue") == "1v1", "Dungeon return did not queue ranked")
	end
	check(last(a, "FillIn") == nil and last(b, "FillIn") == nil, "Asked before auto queuing")
	Duels.pairUp()
	check(Duels.matchOf(a) == nil and Duels.matchOf(b) == nil, "Two auto-queued players were put in a match without being asked")
	check(last(a, "MatchReady") and last(b, "MatchReady"), "Two auto-queued players weren't asked MATCH READY")
	joinAll()
	check(Duels.matchOf(a) ~= nil and Duels.matchOf(a) == Duels.matchOf(b), "Two auto-queued players weren't paired")
	-- Off: no search; switching it off leaves the queue, on joins it.
	local c = makePlayer(83, "QuietMiner")
	c:SetAttribute("Outpost", true)
	check(handlers.DuelAuto(c, false).Ok, "Couldn't turn auto queue off")
	check(not handlers.DuelReturnQueue(c).Ok and c:GetAttribute("DuelQueue") == nil, "Auto queued with it off")
	check(handlers.DuelAuto(c, true).Ok and handlers.DuelReturnQueue(c).Ok and c:GetAttribute("DuelQueue") == "1v1", "Back on, no search")
	check(handlers.DuelAuto(c, false).Ok and c:GetAttribute("DuelQueue") == nil, "Turning auto queue off left them searching")
	print("PASS: auto queue (dungeon blocking, back from a dungeon, paired after MATCH READY), off means no search")
end
