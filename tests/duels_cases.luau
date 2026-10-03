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
check(Matchmaking.window(0) == 100 and Matchmaking.window(20) == 600 and Matchmaking.window(999) == 1000, "Rating window")
local entries = {
	{ Rating = 1000, Since = 0, Size = 1 },
	{ Rating = 1500, Since = 1, Size = 1 },
	{ Rating = 1050, Since = 2, Size = 1 },
	{ Rating = 1000, Since = 3, Size = 2 },
}
local pairs = Matchmaking.pair(entries, 5)
check(#pairs == 1 and pairs[1][1] == 1 and pairs[1][2] == 3, "Closest rating within the window, sizes kept apart")
check(#Matchmaking.pair(entries, 30) == 1, "A wide gap paired before the window allowed it")
check(#Matchmaking.pair({ entries[1], { Rating = 1500, Since = 0, Size = 1 } }, 20) == 1, "A long wait never widened the window")
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
check(not Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({ MatchId = "D2", MatchTeam = 2 })), "Duellists in different matches fight")
check(not Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({ MatchId = "D1", MatchTeam = 1 })), "Teammates fight")
check(Matchmaking.versus(stub({ MatchId = "D1", MatchTeam = 1 }), stub({ MatchId = "D1", MatchTeam = 2 })), "Opponents can't fight")
local a1 = Matchmaking.lane(1, 1, 1, 1)
local b1 = Matchmaking.lane(1, 2, 1, 1)
check((a1 - b1).Magnitude == 16, "Opponents don't face off 16 studs apart")
local t1, t2 = Matchmaking.lane(2, 1, 1, 2), Matchmaking.lane(2, 1, 2, 2)
check(math.abs(t1.X - t2.X) == 5 and t1.Z == t2.Z, "Teammates don't stand side by side")
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
check(ana:GetAttribute("CombatSession") == "Duel" and ana:GetAttribute("PvPEnabled") == true, "Not put in a duel session")
check(ana:GetAttribute("MatchId") == match.Id and ana:GetAttribute("MatchTeam") ~= ben:GetAttribute("MatchTeam"), "Match ids or teams wrong")
check(ana:GetAttribute("DuelQueue") == nil and last(ana, "Queue")[2] == nil, "Still shown as queued")
check((ana.Root.Position - ben.Root.Position).Magnitude > 15, "Not placed facing off in a lane")
check(resets[ana] and resets[ben], "Combat state not reset for the duel")
local info = last(ana, "Match")[2]
check(info.Mode == "1v1" and info.Ranked and #info.Teams == 2 and info.Teams[2][1].Name == "Ben", "Match info wrong")
check(not handlers.DuelQueue(ana, "1v1").Ok and not handlers.DuelChallenge(ana, ben.UserId).Ok, "Queued or challenged mid-duel")
advance(Matchmaking.Countdown)
check(match.State == "Fight" and last(ana, "Fight") ~= nil, "Countdown never ended")
kill(ben)
check(match.State == "Done", "A knockout didn't end the match")
local won, lost = last(ana, "MatchEnd")[2], last(ben, "MatchEnd")[2]
check(won.Won and not lost.Won and won.Delta == 16 and lost.Delta == -16, "Rating change wrong")
check(profiles[ana].Duel.Rating == 1016 and profiles[ana].Duel.Wins == 1 and profiles[ben].Duel.Losses == 1, "Record not saved")
check(profiles[ana].Coins == Matchmaking.Rewards.Ranked.Win and profiles[ben].Coins == Matchmaking.Rewards.Ranked.Loss, "Rewards wrong")
check(xp[ana] == "DuelWin" and xp[ben] == "DuelPlay" and Season.XP[xp[ana]] > Season.XP[xp[ben]], "XP wrong")
check(ana:GetAttribute("DuelRating") == 1016, "Public rating not updated")
check(last(ana, "Feed") ~= nil and string.find(last(ana, "Feed")[2], "Ana defeated Ben", 1, true), "No result in the chat feed")
advance(Matchmaking.EndPause)
check(Duels.matchOf(ana) == nil and ana:GetAttribute("MatchId") == nil and ana:GetAttribute("CombatSession") == nil, "Not released after the match")
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
advance(Matchmaking.Countdown)
ben:SetAttribute("CombatSession", nil) -- the Leave button
check(match.State == "Done" and last(ana, "MatchEnd")[2].Won and last(ana, "MatchEnd")[2].Reason == "Left", "Leaving didn't forfeit")
check(last(ana, "MatchEnd")[2].Delta == 0 and profiles[ana].Duel.Rating == 1016, "A friendly duel changed the rating")
advance(Matchmaking.EndPause)
-- An expired challenge can't be accepted.
check(handlers.DuelChallenge(ana, ben.UserId).Ok, "Second challenge refused")
advance(Matchmaking.ChallengeSeconds + 1)
check(not handlers.DuelRespond(ben, ana.UserId, true).Ok, "Accepted an expired challenge")

-- Time limit: the healthier side wins -------------------------------------------
check(handlers.DuelChallenge(ana, ben.UserId).Ok and handlers.DuelRespond(ben, ana.UserId, true).Ok, "Third duel")
match = Duels.matchOf(ana)
advance(Matchmaking.Countdown)
ana.Humanoid.Health = 100
advance(Matchmaking.TimeLimit)
check(match.State == "Done" and last(ben, "MatchEnd")[2].Won and last(ben, "MatchEnd")[2].Reason == "Time", "Time limit winner wrong")
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

print("PASS: " .. checks .. " duel checks (Elo, pairing, lanes, who can hit whom, queue, challenges, 2v2 parties, knockouts, forfeits, time limit, rewards)")
