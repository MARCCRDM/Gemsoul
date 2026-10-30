--[[
	Auto queue. On (the default), you're in the ranked 1v1 queue whenever
	you're in the lobby, without being asked (arriving there, after your
	first fight, back from a dungeon or the Rift: Systems/Duels'
	DuelReturnQueue); CANCEL on the SEARCHING card leaves it, and turning
	auto queue off leaves it too. Two of you searching are paired.

	The one question: someone queues for a 1v1 and nobody else is
	searching. Instead of waiting on an empty queue, matchmaking calls a
	player from the lobby, and that's asked first:

	  On (the default)       free players receive a timed Join / Not now card.
	                         The first to accept steps in.
	  Off                    no search, no lobby invitations.
	  First fight            +FillBonus coins at successful entry, once per
	                         newcomer's first fight, never paid again at its end.
	  Other 1v1s             keep the existing win bonus and rating protection.

	Just logged in: a moment first. For Settle seconds after you first
	reach the lobby you're searching (auto queue) but not asked anything:
	no MATCH READY and no fill-in card. One question at a time: starting
	your own search takes down a fill-in card you had open, and if that
	same queue is who you're then matched with, the card's bonus comes with
	you (you're called in for it).

	A new player's first fight is a queue of its own ("intro"). On a quiet
	server (fewer than Intro.Populated players) it's the sparring rival at
	once, no search. On a busy one:

	  two new players          paired at once, each in their first fight
	                           (hints pop up as they go, Shared.FastStart)
	  one, after Intro.CallAfter   eligible lobby players are invited
	  one, after Intro.BotAfter    the sparring rival steps in

	Pure: the server (Systems/Duels) applies it, the client shows it, tests
	check it.

	  AutoQueue.Default                    on, until a player turns it off
	  AutoQueue.ready(get, queued)         may this lobby player be called?
	                                       -> ok, reason (`get(name)` reads an
	                                       attribute; `queued`: already searching)
	  AutoQueue.setting(record)            the player's choice (true: on call)
	  AutoQueue.introPhase(waited)         "Search" | "Call" | "Bot"
	  AutoQueue.introSearches(players)     a first fight looks for real
	                                       players (`players` in the server)?
	  AutoQueue.pick(candidates, rating)   the closest in rating ({ Rating })
	  AutoQueue.bonus(called, won)         the fill-in's extra coins
	  AutoQueue.settled(arrivedAt, now)    past the moment after logging in?
	  AutoQueue.holdUntil(arrivedAt, now)  when an auto search may be asked
]]
local AutoQueue = {}

AutoQueue.Default = true
AutoQueue.CallAfter = 8 -- seconds a 1v1 queue waits before the lobby is called
AutoQueue.AskSeconds = 15 -- how long a fill-in offer stands
AutoQueue.FillBonus = 20 -- first-fight join bonus; other fill-ins retain the win bonus
AutoQueue.Settle = 20 -- seconds after you first reach the lobby before you're asked to join anything
AutoQueue.CarryFor = 60 -- seconds a taken-down fill-in card's bonus waits for that same queue
AutoQueue.Intro = {
	Populated = 6, -- players in the server before a first fight looks for real ones (fewer: the rival at once)
	CallAfter = 4, -- seconds alone before lobby invitations
	BotAfter = 10, -- seconds alone before the sparring rival steps in
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

-- Past the moment after logging in: `arrivedAt` is when you first reached
-- the lobby (nil: not yet).
function AutoQueue.settled(arrivedAt: number?, now: number): boolean
	return arrivedAt ~= nil and now - arrivedAt >= AutoQueue.Settle
end

-- When an auto search started now may first be asked MATCH READY.
function AutoQueue.holdUntil(arrivedAt: number?, now: number): number
	return (arrivedAt or now) + AutoQueue.Settle
end

-- Where an intro search is after `waited` seconds alone.
function AutoQueue.introSearches(players: number): boolean
	return players >= AutoQueue.Intro.Populated
end

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
