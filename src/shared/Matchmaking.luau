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
	                              lane, and the lane's centre (offsets from the arena floor's centre)
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

-- Lanes sit around the floor's centre; the two teams face off 16 studs apart,
-- teammates side by side.
local LANE_CENTRES = {
	Vector3.new(-12, 0, -12),
	Vector3.new(12, 0, 12),
	Vector3.new(12, 0, -12),
	Vector3.new(-12, 0, 12),
}
function Matchmaking.lane(slot: number, team: number, index: number, size: number): (Vector3, Vector3)
	local centre = LANE_CENTRES[(slot - 1) % #LANE_CENTRES + 1]
	local side = if team == 1 then -1 else 1
	local across = if size > 1 then (index - (size + 1) / 2) * 5 else 0
	return centre + Vector3.new(across, 0, side * 8), centre
end

return Matchmaking
