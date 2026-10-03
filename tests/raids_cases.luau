-- Party Raids: the shared rules (Shared.Matchmaking.Raid) and the real
-- "PartyRaid" request (Raids.luau). Runs after the duel cases, in the same
-- harness (check, makePlayer, parties, advance ...).
local before = checks
Raids.start()
local R = Matchmaking.Raid

-- The rules ------------------------------------------------------------------------
check(R.Min == 3, "A raid should need three")
local solo = { Health = Matchmaking.raidScale(1, 1) }
local h3, d3 = Matchmaking.raidScale(3, 1)
local h4 = Matchmaking.raidScale(4, 1)
local h3w2, d3w2 = Matchmaking.raidScale(3, 2)
check(solo.Health == 1 and h3 > 2 and h4 > h3, "Boss health doesn't grow with the party")
check(h3w2 > h3 and d3w2 > d3 and d3 > 1, "Later waves aren't tougher")
check(Matchmaking.raidCoins(2) > Matchmaking.raidCoins(1), "Later waves don't pay more")
local function stub(attrs)
	return {
		UserId = attrs.UserId,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
	}
end
check(Matchmaking.ownsRival(stub({ RivalOwner = 7 }), stub({ UserId = 7 })), "Your own rival isn't yours")
check(
	Matchmaking.ownsRival(stub({ RivalOwner = 9, RaidId = "R1" }), stub({ UserId = 7, RaidId = "R1" })),
	"Your raid's boss isn't yours while it chases a teammate"
)
check(
	not Matchmaking.ownsRival(stub({ RivalOwner = 9, RaidId = "R1" }), stub({ UserId = 7, RaidId = "R2" })),
	"Another raid's boss counted as yours"
)
check(not Matchmaking.ownsRival(stub({ RivalOwner = 9 }), stub({ UserId = 7 })), "Someone else's rival counted as yours")

-- The request ------------------------------------------------------------------------
local ra, rb, rc, rd = makePlayer(301, "Ria"), makePlayer(302, "Bo"), makePlayer(303, "Cass"), makePlayer(304, "Dev")
check(not handlers.PartyRaid(ra).Ok, "A solo player started a raid")
local raidParty = { Leader = ra, Members = { ra, rb } }
parties[ra], parties[rb] = raidParty, raidParty
local tooSmall = handlers.PartyRaid(ra)
check(not tooSmall.Ok and string.find(tooSmall.Message, "at least 3", 1, true), "A party of two started a raid")
table.insert(raidParty.Members, rc)
parties[rc] = raidParty
check(not handlers.PartyRaid(rb).Ok, "A member who isn't the leader started a raid")
rc:SetAttribute("Expedition", true)
local away = handlers.PartyRaid(ra)
check(not away.Ok and string.find(away.Message, "Cass", 1, true), "Started without a member who's away (or didn't say who)")
rc:SetAttribute("Expedition", nil)
local started = handlers.PartyRaid(ra)
check(started.Ok, "A ready party of three couldn't start: " .. tostring(started.Message))
for _, member in { ra, rb, rc } do
	check(member:GetAttribute("CombatSession") == "Raid", member.DisplayName .. " not in the raid session")
	check(member:GetAttribute("RaidId") == ra:GetAttribute("RaidId"), member.DisplayName .. " has another raid id")
	check(member:GetAttribute("PvPEnabled") == false, member.DisplayName .. " can be hurt by players")
	check((member.Root.Position - FLOOR).Magnitude < 15, member.DisplayName .. " not brought to the Arena floor")
end
check(rd:GetAttribute("RaidId") == nil, "Someone outside the party was pulled in")
check(#raidsStarted == 0, "The boss came before everyone arrived")
advance(Raids.Delay)
check(#raidsStarted == 1 and #raidsStarted[1].Members == 3, "No boss for the raid")
check(raidsStarted[1].Id == ra:GetAttribute("RaidId"), "Boss started for the wrong raid")
check(not handlers.PartyRaid(ra).Ok, "Started a second raid from inside one")
-- A party of four is welcome too.
local four = makePlayer(305, "Eli")
local fullParty = { Leader = rd, Members = { rd, four, makePlayer(306, "Fen"), makePlayer(307, "Gus") } }
for _, member in fullParty.Members do
	parties[member] = fullParty
end
check(handlers.PartyRaid(rd).Ok, "A party of four couldn't raid")

print("PASS: " .. (checks - before) .. " raid checks (size rules, scaling, who owns the boss, leader-only, busy members, arrival, boss)")
