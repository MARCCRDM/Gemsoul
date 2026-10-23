--[[
	Lobby invitations: every match needs an explicit acceptance.

	Someone queues for a 1v1 and nobody else is searching. Instead of
	waiting on an empty queue, matchmaking calls a player from the lobby:

	  On (the default)       free players receive a timed Join / Not now card.
	                         The first to accept steps in. Saved AutoQueue=true
	                         is permission to receive invitations, never teleport.
	  Off                    no unsolicited lobby invitations.
	  First fight            +FillBonus coins at successful entry, once per
	                         newcomer's first fight, never paid again at its end.
	  Other 1v1s             keep the existing win bonus and rating protection.

	A new player's first fight is a queue of its own ("intro"):

	  two new players          paired at once, each in their first fight
	                           (hints pop up as they go, Shared.FastStart)
	  one, after Intro.CallAfter   eligible lobby players are invited
	  one, after Intro.BotAfter    the sparring rival steps in (the old flow)

	Pure: the server (Systems/Duels) applies it, the client shows it, tests
	check it.

	  AutoQueue.Default                    on, until a player turns it off
	  AutoQueue.ready(get, queued)         may this lobby player be called?
	                                       -> ok, reason (`get(name)` reads an
	                                       attribute; `queued`: already searching)
	  AutoQueue.setting(record)            the player's choice (true: on call)
	  AutoQueue.introPhase(waited)         "Search" | "Call" | "Bot"
	  AutoQueue.pick(candidates, rating)   the closest in rating ({ Rating })
	  AutoQueue.bonus(called, won)         the fill-in's extra coins
]]
local AutoQueue = {}

AutoQueue.Default = true
AutoQueue.CallAfter = 8 -- seconds a 1v1 queue waits before the lobby is called
AutoQueue.AskSeconds = 15 -- how long a fill-in offer stands
AutoQueue.FillBonus = 20 -- first-fight join bonus; other fill-ins retain the win bonus
AutoQueue.Intro = {
	CallAfter = 5, -- seconds alone before lobby invitations
	BotAfter = 15, -- seconds alone before the sparring rival steps in
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

-- The player's choice from their duel record: on call unless switched off.
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

-- The extra coins a fill-in takes home.
function AutoQueue.bonus(called: boolean?, won: boolean?): number
	return if called and won then AutoQueue.FillBonus else 0
end

return AutoQueue
