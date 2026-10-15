--[[
	Friendly sparring in the lobby (the Saga Outpost). Press 1 to swap your
	pickaxe for your combat kit, and 1 again to put it away. With your kit
	out you fight exactly as in a duel (the first-person view, every move,
	gear and gems only), but only against other players who have theirs out
	too: a miner with a pickaxe in hand can't hit you or be hit.

	Nothing is lost. At 0 health you're knocked down for a few seconds,
	then you get up where you fell, at full health, with a moment's guard
	so you can't be knocked straight back down.

	Attributes, on the Player:
	  Spar      true while your combat kit is out (the server sets it)
	  SparDown  server time you get back up, while knocked down
	  SparHurt  server time you were last hit in a spar: you can't put your
	            weapon away in the middle of an exchange

	Pure, for the server, the client and tests:
	  Spar.sparring(player)        kit out (down or not)
	  Spar.isDown(player, now?)    knocked down right now
	  Spar.active(player, now?)    kit out and on your feet: fighting
	  Spar.fighting(player)        in a fight of any kind: an Arena session,
	                               a match, or a spar
	  Spar.canHit(sourceSpar, targetSpar, sourceDown, targetDown, same)
	  Spar.startProblem(state)     why the kit can't come out (nil if it can)
	  Spar.stopWait(state, now)    seconds before it can go away (0 = now)
]]
local Spar = {}

Spar.DownSeconds = 3 -- knocked down this long
Spar.GuardSeconds = 1.5 -- then shielded this long, back on your feet
Spar.SheatheLock = 3 -- no putting the weapon away this soon after a hit

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

-- Can one sparring player hit another? Both kit out, both on their feet,
-- and not themselves. (Teams and parties don't matter: friends spar too.)
function Spar.canHit(sourceSpar: any, targetSpar: any, sourceDown: boolean, targetDown: boolean, same: boolean): boolean
	return sourceSpar == true and targetSpar == true and not sourceDown and not targetDown and not same
end

export type State = {
	Outpost: boolean, -- in the Outpost
	Alive: boolean,
	Seated: boolean, -- in a vehicle or any other seat
	Busy: string?, -- an Arena session, a match, a dungeon or an expedition
	Intro: boolean?, -- the starter picker or tutorial still running
}

-- Why the kit can't come out now, in a few words for the player; nil if it can.
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

-- Seconds before the kit can be put away: never while knocked down (you
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
