--[[
	Auto queue: the lobby gets asked to fill PvP.

	Someone queues for a 1v1 and nobody else is searching. Instead of
	waiting on an empty queue, matchmaking asks the lobby: after `CallAfter`
	seconds the free players on auto queue (the closest in rating first, at
	most `AskMax` of them) each get a card with JOIN and DECLINE, standing
	for `AskSeconds`. Nobody is pulled in without saying yes. The first to
	join steps in, and is paid `JoinBonus` coins on the spot (once every
	`JoinCooldown` seconds, so it can't be farmed by joining and walking
	off); their rating never drops from a match they filled.

	  On (the default)   join offers pop up while you're free in the lobby
	  Off                no offers

	A new player's first fight is a queue of its own ("intro"):

	  two new players          paired at once, each in their first fight
	                           (hints pop up as they go, Shared.FastStart)
	  one, after Intro.CallAfter   the lobby is asked to step in
	  one, after Intro.BotAfter    the sparring rival steps in (the old flow)

	Pure: the server (Systems/Duels) applies it, the client shows it, tests
	check it.

	  AutoQueue.Default                    on, until a player turns it off
	  AutoQueue.ready(get, queued)         may this lobby player be asked?
	                                       -> ok, reason (`get(name)` reads an
	                                       attribute; `queued`: already searching)
	  AutoQueue.setting(record)            the player's choice (true: offers on)
	  AutoQueue.introPhase(waited)         "Search" | "Call" | "Bot"
	  AutoQueue.pick(candidates, rating)   the closest in rating ({ Rating })
	  AutoQueue.askList(candidates, rating) the ones to ask, closest first, AskMax at most
	  AutoQueue.joinBonus(lastAt, now)     the coins for joining now (0 inside the cooldown)
]]
local AutoQueue = {}

AutoQueue.Default = true
AutoQueue.CallAfter = 8 -- seconds a 1v1 queue waits before the lobby is asked
AutoQueue.AskSeconds = 15 -- how long a join offer stands
AutoQueue.AskMax = 4 -- lobby players asked per queue, the closest in rating
AutoQueue.JoinBonus = 25 -- coins paid the moment you join someone's queue
AutoQueue.JoinCooldown = 180 -- seconds before joining pays again
AutoQueue.Intro = {
	CallAfter = 5, -- seconds alone before the lobby is asked
	BotAfter = 22, -- seconds alone before the sparring rival steps in (the ask's time, and a little)
}
AutoQueue.IntroMode = "intro"

-- Attributes that mean "not free": in a fight, away, or in the middle of
-- something the match would tear them out of.
AutoQueue.Busy = {
	{ "CombatSession", "is in an Arena session" },
	{ "MatchId", "is already in a duel" },
	{ "Expedition", "is on an expedition" },
	{ "RiftRun", "is in the Rift" },
	{ "DungeonQueue", "is waiting for a dungeon" },
	{ "DungeonId", "is in a dungeon" },
	{ "KaijuBattle", "is in a kaiju battle" },
	{ "Spar", "is sparring" },
	{ "SparDown", "is down" },
	{ "MechPilot", "is driving a mech" },
	{ "FirstFight", "is in their first fight" },
}

-- Whether a lobby player can be called right now. `get(name)` reads one of
-- their attributes; `queued` is true when they're searching themselves (the
-- queue pairs them instead).
function AutoQueue.ready(get: (string) -> any, queued: boolean?): (boolean, string?)
	if not get("Outpost") then
		return false, "isn't in the lobby"
	end
	if queued or get("DuelQueue") then
		return false, "is searching already"
	end
	for _, entry in AutoQueue.Busy do
		if get(entry[1]) then
			return false, entry[2]
		end
	end
	return true, nil
end

-- The player's choice from their duel record: offers on unless switched off.
function AutoQueue.setting(record): boolean
	if record and record.AutoQueue == false then
		return false
	end
	return AutoQueue.Default
end

-- Where an intro search is after `waited` seconds alone.
function AutoQueue.introPhase(waited: number): string
	if waited >= AutoQueue.Intro.BotAfter then
		return "Bot"
	elseif waited >= AutoQueue.Intro.CallAfter then
		return "Call"
	end
	return "Search"
end

-- The candidate ({ Rating, ... }) closest in rating to `rating`; ties go to
-- the earlier one.
function AutoQueue.pick(candidates, rating: number)
	local best, gap = nil, math.huge
	for _, candidate in candidates do
		local distance = math.abs((candidate.Rating or rating) - rating)
		if distance < gap then
			best, gap = candidate, distance
		end
	end
	return best
end

-- The lobby players to ask: the closest in rating first, AskMax at most.
function AutoQueue.askList(candidates, rating: number)
	local sorted = table.clone(candidates)
	table.sort(sorted, function(a, b)
		local da, db = math.abs((a.Rating or rating) - rating), math.abs((b.Rating or rating) - rating)
		return da < db
	end)
	local out = {}
	for i = 1, math.min(#sorted, AutoQueue.AskMax) do
		out[i] = sorted[i]
	end
	return out
end

-- The coins for joining now: the bonus, unless the last one was paid
-- inside the cooldown.
function AutoQueue.joinBonus(lastAt: number?, now: number): number
	if lastAt and now - lastAt < AutoQueue.JoinCooldown then
		return 0
	end
	return AutoQueue.JoinBonus
end

return AutoQueue
