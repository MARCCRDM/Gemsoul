--[[
	The Meteor Golem: a new miner's first boss, once. Ten seconds after their
	first swing at a rock out in the quarry (their intro done), a meteor
	streaks down near them and slams into the ground; the rock in its crater
	cracks open and a Magma Golem climbs out (Server.MeteorGolemServer, its
	fall and its cinematic: Client.MeteorGolemFx). It's slow and every blow
	it throws is telegraphed: a glowing ring on the ground first, Slam's
	under it and round it, a hurled Rock's where you stand. Beaten, it
	crumbles, and its cache is a boss cache of threat I (Shared.BossLoot: two
	pieces of gear, at least Uncommon, one to keep, the other to the Market),
	with no kaiju roll. It's theirs alone (the reward is), and it comes once:
	walked away from or lost to, it comes again at their next swing a while
	later (Retry).

	Pure, for the server, the client and tests.

	  MeteorGolem.Boss            the cache's boss (a DungeonRules.Bosses-like entry)
	  MeteorGolem.Delay           seconds from that first swing to the meteor
	  MeteorGolem.Fall, Crack, Rise   the cinematic's beats, from the meteor's start
	  MeteorGolem.Health, Speed, Level, Scale
	  MeteorGolem.Slam, Rock      its two blows: Windup, Radius, Share (of
	                              the player's max health), Reach
	  MeteorGolem.Every           seconds between its blows
	  MeteorGolem.eligible(profile, attrs) -> boolean, reason?
	  MeteorGolem.blow(distance, rocksSinceSlam) -> "Slam" | "Rock" | nil
]]
local MeteorGolem = {}

MeteorGolem.Id = "MeteorGolem"
MeteorGolem.Boss = {
	Id = "MeteorGolem",
	Name = "Magma Golem",
	Element = "Fire",
	Weakness = "Frost",
	Threat = 1, -- (BossLoot: an Uncommon floor, two pieces, one kept)
	Loot = nil,
}

MeteorGolem.Delay = 10
-- The cinematic, in seconds from the meteor's start: it falls for Fall, the
-- rock in the crater starts cracking at Crack, the golem climbs out from
-- Rise to Awake, and it's yours to fight at Awake.
MeteorGolem.Fall = 3
MeteorGolem.Crack = 3.9
MeteorGolem.Rise = 4.8
MeteorGolem.Awake = 6.6
MeteorGolem.Land = 30 -- studs ahead of you it comes down
MeteorGolem.Retry = 60 -- seconds before it can come again, if it didn't end in a win
MeteorGolem.Leash = 140 -- studs from its crater: further and it gives up
MeteorGolem.LeashTime = 15 -- seconds you can be past the Leash before it does

-- Easy, but not that easy: slow, every blow telegraphed, a handful of
-- blows to bring you down if you stand in them.
MeteorGolem.Health = 1500
MeteorGolem.Speed = 9
MeteorGolem.Level = 3
MeteorGolem.Scale = 1 -- (its rig is built at its full size: about 13 studs)
MeteorGolem.Every = 2.6
MeteorGolem.Slam = { Windup = 1.15, Radius = 9, Share = 0.2, Reach = 11 }
MeteorGolem.Rock = { Windup = 1.3, Radius = 6, Share = 0.14, Reach = 45, Flight = 0.8 }

-- Whether `profile`'s player (their attributes in `attrs`) may be sent it now.
function MeteorGolem.eligible(profile, attrs): (boolean, string?)
	if type(profile) ~= "table" then
		return false, "no profile"
	end
	if not (profile.Intro and profile.Intro.Done) then
		return false, "intro"
	end
	if profile.Milestones and profile.Milestones[MeteorGolem.Id] then
		return false, "beaten"
	end
	attrs = attrs or {}
	if attrs.Outpost ~= true then
		return false, "not in the Outpost"
	end
	for _, busy in { "CombatSession", "MatchId", "FirstFight", "IntroCover", "DungeonId", "MechPilot", "KaijuBattle" } do
		if attrs[busy] ~= nil and attrs[busy] ~= false then
			return false, busy
		end
	end
	return true
end

-- Which blow, with the player `distance` studs away: a Slam close in, a
-- Rock from further out (never three Rocks running: it closes in instead),
-- else nothing (it walks).
function MeteorGolem.blow(distance: number, rocksSinceSlam: number?): string?
	if distance <= MeteorGolem.Slam.Reach then
		return "Slam"
	end
	if distance <= MeteorGolem.Rock.Reach and (rocksSinceSlam or 0) < 2 then
		return "Rock"
	end
	return nil
end

return MeteorGolem
