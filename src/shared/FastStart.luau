--[[
	The fast start: a new player's first minute.

	  1. Pick a fighting style (Prospector, Skirmisher, Juggernaut): the
	     armor set they start in (Shared.ArmorFamilies).
	  2. Independently pick an element (Thermal, Cryo, Ion, Corrosive),
	     with the two showcase moves each of Q / E / R can roll (GemTraits.Intro).
	  3. The kit goes on (Shared.StarterLottery, granted by Systems/Intro):
	     one move rolled per key, shown on a reveal card before the fight.
	  4. A first fight: an easy sparring match (Systems/Duelist, FirstFight),
	     with a hint popping up the first time each control is useful
	     (Client FirstFight). Then the lobby.

	Pure, for the server, the client and tests.

	  FastStart.Enabled                  off = no picker and no first fight
	  FastStart.Styles / Elements        in the order the screens show them
	  FastStart.SaveVersion              saves older than this were made before
	                                     the fast start (see migrate)
	  FastStart.migrate(profile)         -> true when an old save that never
	                                        finished the intro is marked done
	  FastStart.hint(view, done)         -> the hint to show now, or nil
	  FastStart.text(id, touch, moves)   -> the hint's line and its reason
	  FastStart.complete(done, event)    ticks off what `event` taught
]]
local FastStart = {}

FastStart.Enabled = true
FastStart.Styles = { "Prospector", "Skirmisher", "Juggernaut" }
FastStart.Elements = { "Fire", "Frost", "Shock", "Poison" }
-- Each style's own gem (as its armor art shows it).

-- Saves from before the fast start: anyone who has been playing without
-- finishing the intro (it was switched off) is not sent through it now,
-- which would swap their gear for a starter kit. New saves start at this
-- version, so only brand-new accounts see it.
FastStart.SaveVersion = 11
function FastStart.migrate(profile): boolean
	if (profile.Version or 1) >= FastStart.SaveVersion then
		return false
	end
	local intro = profile.Intro
	if intro and not intro.Done then
		intro.Done = true
		intro.Skipped = "FastStart"
		return true
	end
	return false
end

-- The first fight's hints, most urgent first. Urgent ones show only while
-- the threat lasts; the others until they're done.
FastStart.Order = { "Dodge", "Block", "Swing", "Heavy", "Q", "E", "R" }
FastStart.Urgent = { Dodge = true, Block = true }

-- view: what's happening this moment.
--   FoeSlash  the foe is winding up a quick swing
--   FoeHeavy  the foe is winding up a Heavy Blow
--   FoeGuard  the foe's guard is up
--   Ready     { Q = bool, E = bool, R = bool }: off cooldown and affordable
-- done: { [hint id] = true } for what's been done already.
function FastStart.hint(view, done): string?
	if view.FoeHeavy and not done.Dodge then
		return "Dodge"
	end
	if view.FoeSlash and not done.Block then
		return "Block"
	end
	if not done.Swing then
		return "Swing"
	end
	if view.FoeGuard and not done.Heavy then
		return "Heavy"
	end
	local ready = view.Ready or {}
	for _, key in { "Q", "E", "R" } do
		if ready[key] and not done[key] then
			return key
		end
	end
	return nil
end

-- What each thing you do teaches: a landed heavy is also a swing.
function FastStart.complete(done, event: string)
	if event == "Heavy" then
		done.Heavy, done.Swing = true, true
	elseif event == "Hit" then
		done.Swing = true
	elseif event == "Block" or event == "Dodge" or event == "Q" or event == "E" or event == "R" then
		done[event] = true
	end
end

-- Has every hint been shown and done?
function FastStart.finished(done): boolean
	for _, id in FastStart.Order do
		if not done[id] then
			return false
		end
	end
	return true
end

local TEXT = {
	Swing = { "CLICK to swing your sword", "TAP ATTACK to swing your sword", "Land a hit" },
	Block = { "HOLD RIGHT MOUSE to block", "HOLD GUARD to block", "It's winding up a swing" },
	Dodge = { "PRESS SPACE to dodge", "TAP DODGE to get out", "Heavy Blow: it breaks your guard" },
	Heavy = {
		"HOLD LEFT MOUSE, release for a heavy",
		"HOLD ATTACK, release for a heavy",
		"Its guard is up: a heavy breaks it",
	},
	Q = { "PRESS Q: %s", "TAP Q: %s", "Your sword gem's move" },
	E = { "PRESS E: %s", "TAP E: %s", "Your core gem's move" },
	R = { "PRESS R: %s", "TAP R: %s", "Your defense move (uses Stamina)" },
}

-- The hint's line (what to press) and its reason. `moves` names the Q / E / R moves.
function FastStart.text(id: string, touch: boolean?, moves: { [string]: string }?): (string, string)
	local entry = TEXT[id]
	if not entry then
		return "", ""
	end
	local line = if touch then entry[2] else entry[1]
	if string.find(line, "%%s") then
		line = string.format(line, string.upper(moves and moves[id] or "your move"))
	end
	return line, entry[3]
end

return FastStart
