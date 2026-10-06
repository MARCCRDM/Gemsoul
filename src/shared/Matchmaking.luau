--[[
	Arena duels between players: the rules both sides share.

	  Modes                       "1v1" (solo) and "2v2" (a party of two)
	  Matchmaking.versus(a, b)    may these two players hurt each other? Duel
	                              opponents only, and never your own party
	  Matchmaking.expected(r, s)  Elo: the chance rating r beats rating s
	  Matchmaking.rated(r, s, won)  r's new rating after a rated match
	  Matchmaking.window(seconds)   how far apart in rating two entries may be
	                              matched, widening the longer they wait
	  Matchmaking.pair(entries, now)  pairs queue entries ({ Rating, Since,
	                              Size }), longest-waiting first
	  Matchmaking.lane(slot, team, index, size)  where a fighter stands in a
	                              lane, and the point it faces (offsets from the arena floor's centre)

	Party Raids (PvE): a party of at least Raid.Min fights one raid boss.
	  Matchmaking.Raid                 the rules: size, scaling, rewards
	  Matchmaking.raidScale(n, wave)   the boss's health and damage multipliers
	                                   for n raiders on a wave
	  Matchmaking.raidCoins(wave)      each raider's coins for clearing a wave
	  Matchmaking.raidCheck(members, leader, busy)  may this party start a
	                                   raid? (ok, reason)
	  Matchmaking.ownsRival(model, player)  is this Arena rival yours (your
	                                   own, or your raid's boss)?
]]
local Matchmaking = {}

Matchmaking.Modes = {
	["1v1"] = { Name = "1v1 Duel", Size = 1 },
	["2v2"] = { Name = "2v2 Party Duel", Size = 2 },
}
Matchmaking.StartRating = 1000
Matchmaking.K = 32
Matchmaking.Countdown = 4 -- seconds: shielded, facing off
Matchmaking.TimeLimit = 120 -- seconds: then the healthier side wins
Matchmaking.EndPause = 4 -- seconds on the result before heading back
Matchmaking.ChallengeSeconds = 30
Matchmaking.Lanes = 4 -- duels running side by side in the Arena
Matchmaking.Rewards = {
	Ranked = { Win = 40, Loss = 10 },
	Friendly = { Win = 15, Loss = 5 },
}

Matchmaking.Raid = {
	Min = 3, -- raiders needed to start
	Max = 4, -- a full party
	HealthPerRaider = 0.85, -- the boss's extra health for each raider past the first
	HealthPerWave = 0.25, -- and for each wave cleared
	Damage = 1.2, -- it hits harder than a duelling rival
	DamagePerWave = 0.1,
	Coins = 60, -- each raider's coins for wave 1
	CoinsPerWave = 20,
	NextWave = 8, -- seconds between waves
}

function Matchmaking.raidScale(raiders: number, wave: number): (number, number)
	local r = Matchmaking.Raid
	local n, w = math.max(1, raiders), math.max(1, wave)
	local health = (1 + r.HealthPerRaider * (n - 1)) * (1 + r.HealthPerWave * (w - 1))
	local damage = r.Damage + r.DamagePerWave * (w - 1)
	return health, damage
end

function Matchmaking.raidCoins(wave: number): number
	return Matchmaking.Raid.Coins + Matchmaking.Raid.CoinsPerWave * (math.max(1, wave) - 1)
end

-- `members`: the party, leader first or not; `busy(player)`: why that member
-- can't come right now (a string), or nil.
function Matchmaking.raidCheck(members, leader, busy): (boolean, string?)
	if not members or members[1] == nil then
		return false, string.format("Form a party of %d first (Social > Party).", Matchmaking.Raid.Min)
	end
	if not table.find(members, leader) then
		return false, "Only your party's leader can start a raid."
	end
	if #members < Matchmaking.Raid.Min then
		return false,
			string.format(
				"A raid needs at least %d in the party (you have %d). Invite more!",
				Matchmaking.Raid.Min,
				#members
			)
	end
	for _, member in members do
		local why = busy(member)
		if why then
			return false, why
		end
	end
	return true, nil
end

-- A match or party id: a string attribute, or nil.
local function attribute(player, name: string): string?
	local value = if player and player.GetAttribute then player:GetAttribute(name) else nil
	return if type(value) == "string" then value else nil
end

-- Fighters in a duel only fight their opponents in it; party members never
-- fight each other.
function Matchmaking.versus(a, b): boolean
	local matchA, matchB = attribute(a, "MatchId"), attribute(b, "MatchId")
	if matchA ~= nil or matchB ~= nil then
		return matchA == matchB and a:GetAttribute("MatchTeam") ~= b:GetAttribute("MatchTeam")
	end
	local partyA = attribute(a, "PartyId")
	return partyA == nil or partyA ~= attribute(b, "PartyId")
end

-- Your own Arena rival, or the boss your raid is fighting.
function Matchmaking.ownsRival(model, player): boolean
	if not model or not player then
		return false
	end
	local dungeon = attribute(model, "DungeonId")
	if dungeon then
		return dungeon == attribute(player, "DungeonId")
	end
	if player.UserId ~= nil and model:GetAttribute("RivalOwner") == player.UserId then
		return true
	end
	local raid = attribute(model, "RaidId")
	return raid ~= nil and raid == attribute(player, "RaidId")
end

function Matchmaking.expected(rating: number, other: number): number
	return 1 / (1 + 10 ^ ((other - rating) / 400))
end

function Matchmaking.rated(rating: number, other: number, won: boolean): number
	local change = Matchmaking.K * ((if won then 1 else 0) - Matchmaking.expected(rating, other))
	return math.max(100, math.floor(rating + change + 0.5))
end

function Matchmaking.window(seconds: number): number
	return math.min(1000, 100 + 25 * math.max(0, seconds))
end

-- Returns { { i, j } } index pairs into `entries`. The longest-waiting entry
-- takes the closest rating inside the wider of the two windows.
function Matchmaking.pair(entries, now: number)
	local order = {}
	for i in entries do
		table.insert(order, i)
	end
	table.sort(order, function(x, y)
		return entries[x].Since < entries[y].Since
	end)
	local taken, pairs = {}, {}
	for _, i in order do
		if not taken[i] then
			local best, gap = nil, math.huge
			for _, j in order do
				if j ~= i and not taken[j] and entries[j].Size == entries[i].Size then
					local window =
						math.max(Matchmaking.window(now - entries[i].Since), Matchmaking.window(now - entries[j].Since))
					local distance = math.abs(entries[i].Rating - entries[j].Rating)
					if distance <= window and distance < gap then
						best, gap = j, distance
					end
				end
			end
			if best then
				taken[i], taken[best] = true, true
				table.insert(pairs, { i, best })
			end
		end
	end
	return pairs
end

-- Fighters enter as in the Arena intro (you and the rival): across the
-- floor from each other through its centre, 40 studs apart, facing in. Each
-- match at once (its slot) gets its own line through the centre, turned 45
-- degrees from the last; teammates stand side by side, 5 studs apart.
Matchmaking.FaceOff = 20 -- each team's distance from the centre
function Matchmaking.lane(slot: number, team: number, index: number, size: number): (Vector3, Vector3)
	local angle = math.rad(((slot - 1) % Matchmaking.Lanes) * 45)
	local axis = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local beside = Vector3.new(axis.Z, 0, -axis.X)
	local side = if team == 1 then -1 else 1
	local across = if size > 1 then (index - (size + 1) / 2) * 5 else 0
	return axis * (side * Matchmaking.FaceOff) + beside * across, Vector3.new(0, 0, 0)
end

return Matchmaking
