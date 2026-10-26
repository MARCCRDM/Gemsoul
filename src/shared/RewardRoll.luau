--[[
	RewardRoll: every reward is a roll of two pieces of gear. You keep one;
	the other goes up on the Market (the Arena Vault or the Rift Vault) and
	you get ArenaStreak.Commission of its price when it sells.

	How rare the two are goes by how much you've played 1v1 (Plays: every
	1v1 you've finished, won, lost or drawn). The more you play, the further
	up the ladder (Bands) you are, and the better your odds. A reward's
	source can set a floor (a 50-win streak's cache is Ultra-Rare at least,
	a threat III boss's too): a roll under it comes up to it.

	Where they come from:
	  - every 1v1 you win (queued, Ranked or Casual; not a challenge, not a
	    first fight; not the same player twice running): a WIN REWARD;
	  - Ranked win streaks (10, 20 ... 200 in a row): an Arena Cache, coins
	    and a title as before (Shared.ArenaStreak);
	  - a boss beaten (the Rift's, a pathway dungeon's): a boss cache, one
	    of the two its favourite kind (Shared.BossLoot).

	  RewardRoll.Rarities                     Common ... Legendary (GemConfig tiers)
	  RewardRoll.Bands                        the ladder (below)
	  RewardRoll.plays(record) -> number      1v1s played (a Duel record)
	  RewardRoll.count(record)                one more played
	  RewardRoll.band(plays) -> band, index, next?   where you are on it
	  RewardRoll.rarity(plays, floor?, r) -> name    one roll (r: 0..1)
	  RewardRoll.rarities(plays, floor?, rng, n?) -> { name }   a reward's n
	  RewardRoll.quality(rarity, least?) -> 1..4     a piece's quality roll
	  RewardRoll.odds(plays, floor?) -> { [name]: share }   for the screen
	  RewardRoll.pays(record, opponentId) -> bool    does this win pay one?
]]
local RewardRoll = {}

RewardRoll.Offered = 2 -- pieces rolled
RewardRoll.Picks = 1 -- of which you keep
RewardRoll.Waiting = 12 -- win rewards waiting unclaimed at most (past it, none till you claim)

RewardRoll.Rarities = { "Common", "Uncommon", "Rare", "UltraRare", "Legendary" }
RewardRoll.Tier = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }

-- The ladder: from Plays 1v1s on, each rarity's share (percent) of a roll.
RewardRoll.Bands = {
	{ Plays = 0, Name = "Rookie", Odds = { Common = 50, Uncommon = 35, Rare = 13, UltraRare = 2, Legendary = 0 } },
	{ Plays = 10, Name = "Regular", Odds = { Common = 35, Uncommon = 38, Rare = 20, UltraRare = 6, Legendary = 1 } },
	{ Plays = 25, Name = "Veteran", Odds = { Common = 20, Uncommon = 35, Rare = 32, UltraRare = 11, Legendary = 2 } },
	{ Plays = 50, Name = "Elite", Odds = { Common = 8, Uncommon = 27, Rare = 40, UltraRare = 21, Legendary = 4 } },
	{ Plays = 100, Name = "Champion", Odds = { Common = 0, Uncommon = 15, Rare = 42, UltraRare = 35, Legendary = 8 } },
	{ Plays = 200, Name = "Warlord", Odds = { Common = 0, Uncommon = 5, Rare = 35, UltraRare = 45, Legendary = 15 } },
	{ Plays = 400, Name = "Legend", Odds = { Common = 0, Uncommon = 0, Rare = 25, UltraRare = 50, Legendary = 25 } },
}

-- A piece's quality roll (1-4) by its rarity.
RewardRoll.Quality = { Common = 1, Uncommon = 2, Rare = 2, UltraRare = 3, Legendary = 4 }

function RewardRoll.plays(record): number
	if type(record) ~= "table" then
		return 0
	end
	-- (A record from before it was counted starts from its 1v1 wins.)
	return math.max(0, math.floor(tonumber(record.OneVOne) or tonumber(record.Solo) or 0))
end

function RewardRoll.count(record)
	if type(record) == "table" then
		record.OneVOne = RewardRoll.plays(record) + 1
	end
end

function RewardRoll.band(plays: number)
	local at = 1
	for i, band in RewardRoll.Bands do
		if plays >= band.Plays then
			at = i
		end
	end
	return RewardRoll.Bands[at], at, RewardRoll.Bands[at + 1]
end

-- Each rarity's share (0..1) at `plays`, a floor's lower rarities folded
-- up into it.
function RewardRoll.odds(plays: number, floor: string?)
	local band = RewardRoll.band(plays)
	local least = RewardRoll.Tier[floor or "Common"] or 1
	local shares, total = {}, 0
	for _, name in RewardRoll.Rarities do
		total += band.Odds[name] or 0
	end
	for _, name in RewardRoll.Rarities do
		local into = if RewardRoll.Tier[name] < least then RewardRoll.Rarities[least] else name
		shares[into] = (shares[into] or 0) + (band.Odds[name] or 0) / math.max(total, 1)
	end
	for _, name in RewardRoll.Rarities do
		shares[name] = shares[name] or 0
	end
	return shares
end

-- One roll at `plays` (`r` 0..1, a random draw), at least `floor`.
function RewardRoll.rarity(plays: number, floor: string?, r: number): string
	local shares = RewardRoll.odds(plays, floor)
	local acc = 0
	for _, name in RewardRoll.Rarities do
		acc += shares[name]
		if r < acc then
			return name
		end
	end
	-- (r at 1, or rounding: the rarest it could be)
	for i = #RewardRoll.Rarities, 1, -1 do
		local name = RewardRoll.Rarities[i]
		if shares[name] > 0 then
			return name
		end
	end
	return floor or "Common"
end

-- A reward's `n` (Offered) rarities, each rolled on its own.
function RewardRoll.rarities(plays: number, floor: string?, rng: Random, n: number?): { string }
	local list = {}
	for i = 1, n or RewardRoll.Offered do
		list[i] = RewardRoll.rarity(plays, floor, rng:NextNumber())
	end
	return list
end

function RewardRoll.quality(rarity: string, least: number?): number
	return math.clamp(math.max(RewardRoll.Quality[rarity] or 1, least or 1), 1, 4)
end

-- Does a 1v1 win over `opponentId` pay a win reward? Not over the same
-- player twice running (no trading wins with a friend).
function RewardRoll.pays(record, opponentId: number?): boolean
	return type(record) == "table" and (opponentId == nil or record.RewardLastBeaten ~= opponentId)
end

return RewardRoll
