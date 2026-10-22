--[[
	Friendly sparring in the lobby (the Saga Outpost). A spar is asked for
	and agreed to: walk up to another player and press Z (or 1, for the
	nearest), and they get a card to accept or decline. Once they accept,
	both of you swap your pickaxes for your combat kits and fight exactly as
	in a duel (the first-person view, every move, gear and gems only), but
	only each other: nobody else can hit either of you, or be hit. Press 1
	to end it, for both of you.

	Nothing is lost. At 0 health you're knocked down for a few seconds,
	then you get up where you fell, at full health, with a moment's guard
	so you can't be knocked straight back down.

	A creature's finishing blow in the Outpost is another matter: it kills
	you (Killed). Out past the core the critters rob you first (Server.
	Robbery); in the core, where your gems are safe, you lie dead for
	DeadSeconds. Either way you're back at base after, on your feet
	(Server.FrontierServer). A spar between players is never a kill.

	Attributes, on the Player:
	  Spar      true while your combat kit is out (the server sets it)
	  Hunt      true while it's out to hunt (with Spar)
	  SparWith  your partner's UserId, while sparring
	  SparDown  server time you get back up, while knocked down
	  Killed    true while you lie killed by a creature in the Outpost (with
	            SparDown): you go back to base, not up where you fell
	  SparHurt  server time you were last hit in a spar: you can't end it
	            in the middle of an exchange

	Pure, for the server, the client and tests:
	  Spar.sparring(player)        kit out (down or not)
	  Spar.isDown(player, now?)    knocked down right now
	  Spar.active(player, now?)    kit out and on your feet: fighting
	  Spar.fighting(player)        in a fight of any kind: an Arena session,
	                               a match, or a spar
	  Spar.inMatch(player)         in a real fight away from the lobby: a
	                               rival, a duel, a dungeon, an expedition
	  Spar.knocksDown(player)      a finishing blow knocks you down (in the
	                               lobby only: a spar, a hunt, a critter
	                               catching a miner), never in a match
	  Spar.hunting(player)         the kit out alone, to hunt the Outpost's
	                               creatures (KaijuWilds): a spar with no
	                               partner, so no player can hit you or be hit
	  Spar.paired(a, b)            sparring with each other
	  Spar.canHit(sourceSpar, targetSpar, sourceDown, targetDown, same, paired)
	  Spar.startProblem(state)     why you can't spar now (nil if you can)
	  Spar.askProblem(ask)         why you can't ask someone (nil if you can)
	  Spar.stopWait(state, now)    seconds before it can end (0 = now)
]]
local Spar = {}

Spar.DownSeconds = 3 -- knocked down this long
Spar.DeadSeconds = 4 -- killed in the Outpost's core: dead this long, then back at base
Spar.GuardSeconds = 1.5 -- then shielded this long, back on your feet
Spar.SheatheLock = 3 -- no ending the spar this soon after a hit
Spar.AskSeconds = 20 -- a request stays open this long
Spar.AskRange = 30 -- studs: ask someone near you (the prompt is 10)
Spar.AskAgain = 15 -- after a no (or no answer), wait this long to ask them again
Spar.AskGap = 1.5 -- between any two requests of yours
Spar.MaxApart = 150 -- studs: further apart than this, the spar is over

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

function Spar.sparring(player: Instance): boolean
	return player:GetAttribute("Spar") == true
end

function Spar.isDown(player: Instance, now: number?): boolean
	local up = player:GetAttribute("SparDown")
	return type(up) == "number" and up > (now or serverNow())
end

function Spar.active(player: Instance, now: number?): boolean
	return Spar.sparring(player) and not Spar.isDown(player, now)
end

function Spar.fighting(player: Instance): boolean
	return player:GetAttribute("CombatSession") ~= nil or player:GetAttribute("MatchId") ~= nil or Spar.sparring(player)
end

function Spar.inMatch(player: Instance): boolean
	for _, name in { "CombatSession", "MatchId", "DungeonId", "Expedition" } do
		if player:GetAttribute(name) ~= nil then
			return true
		end
	end
	return false
end

-- Knock-downs are the lobby's: in a rival fight, a 1v1, a dungeon or an
-- expedition a finishing blow finishes you (the Outpost flag stays on
-- through a match started from the lobby, so it alone isn't enough).
function Spar.knocksDown(player: Instance): boolean
	if Spar.inMatch(player) then
		return false
	end
	return Spar.sparring(player) or player:GetAttribute("Outpost") == true
end

function Spar.hunting(player: Instance): boolean
	return player:GetAttribute("Hunt") == true and Spar.sparring(player)
end

-- Your partner's UserId while you spar.
function Spar.partner(player: Instance): number?
	local id = player:GetAttribute("SparWith")
	return if Spar.sparring(player) and type(id) == "number" then id else nil
end

-- Sparring with each other (both agreed: each has the other as partner).
function Spar.paired(a: any, b: any): boolean
	return a ~= b and Spar.partner(a) == b.UserId and Spar.partner(b) == a.UserId
end

-- Can one sparring player hit another? Both kit out, partners, both on
-- their feet, and not themselves. (Teams and parties don't matter: friends
-- spar too.)
function Spar.canHit(
	sourceSpar: any,
	targetSpar: any,
	sourceDown: boolean,
	targetDown: boolean,
	same: boolean,
	paired: boolean
): boolean
	return sourceSpar == true
		and targetSpar == true
		and paired == true
		and not sourceDown
		and not targetDown
		and not same
end

export type State = {
	Outpost: boolean, -- in the Outpost
	Alive: boolean,
	Seated: boolean, -- in a vehicle or any other seat
	Busy: string?, -- an Arena session, a match, a dungeon or an expedition
	Intro: boolean?, -- the starter picker or tutorial still running
}

-- Why you can't spar now, in a few words for the player; nil if you can.
function Spar.startProblem(state: State): string?
	if state.Busy then
		return "Finish your fight first."
	elseif not state.Outpost then
		return "Head to the Outpost to spar."
	elseif not state.Alive then
		return "Not right now."
	elseif state.Intro then
		return "Finish getting started first."
	elseif state.Seated then
		return "Hop out of the machine first."
	end
	return nil
end

export type Ask = {
	Here: boolean, -- the other player is in the server (and isn't you)
	Name: string, -- their display name
	Mine: State, -- yours
	Theirs: State, -- theirs
	MyPartner: string?, -- who you're sparring with now
	TheirPartner: string?, -- who they're sparring with now
	Distance: number?, -- studs between you
	Asked: boolean?, -- you've asked them already and it's still open
	Wait: number?, -- seconds before you can ask them again
}

-- Why you can't ask someone to spar now, for the player; nil if you can.
function Spar.askProblem(ask: Ask): string?
	if not ask.Here then
		return "That player isn't here."
	end
	local mine = Spar.startProblem(ask.Mine)
	if mine then
		return mine
	elseif ask.MyPartner then
		return "You're already sparring with " .. ask.MyPartner .. "."
	elseif ask.TheirPartner then
		return ask.Name .. " is already sparring."
	elseif Spar.startProblem(ask.Theirs) then
		return ask.Name .. " can't spar right now."
	elseif type(ask.Distance) ~= "number" or ask.Distance > Spar.AskRange then
		return "Get closer to " .. ask.Name .. " to ask."
	elseif ask.Asked then
		return "You've asked " .. ask.Name .. " already."
	elseif ask.Wait and ask.Wait > 0 then
		return "Give " .. ask.Name .. " a moment before asking again."
	end
	return nil
end

-- Seconds before the spar can end: never while knocked down (you
-- get up first), and not within SheatheLock of being hit.
function Spar.stopWait(state: { Down: number?, Hurt: number? }, now: number): number
	local wait = 0
	if type(state.Down) == "number" and state.Down > now then
		wait = state.Down - now
	end
	if type(state.Hurt) == "number" then
		wait = math.max(wait, state.Hurt + Spar.SheatheLock - now)
	end
	return math.max(0, wait)
end

return Spar
