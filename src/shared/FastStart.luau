--[[
	The fast start: a new player's first minute.

	  1. Their element, rolled for them (no picker, Pick off): Thermal or
	     Cryo at random (StarterElements), shown landing on a quick reel,
	     in the Prospector armor (DefaultStyle: no style picker, never
	     shown). The server rolls it.
	  2. The kit goes on (Shared.StarterLottery, granted by Systems/Intro):
	     one move rolled per key (Q / E / R), the surge roll, moving on by
	     itself.
	  3. A first fight, behind the loading screen till it starts (no
	     inventory or lobby in between): the sparring rival at once, unless
	     the server's busy enough to find another new miner
	     (Shared.AutoQueue.Intro.Populated). A hint pops up the first time
	     each control is useful (Client FirstFight). Then the lobby.
	  Kaiju aren't in it: the starter kaiju roll is Wren's, at the Kennel
	  (Shared.Vendors' KaijuKeeper), once they're in the Outpost.

	(Pick on: the old picker, a fighting style then any of the four
	elements.)

	Pure, for the server, the client and tests.

	  FastStart.Enabled                  off = no picker and no first fight
	  FastStart.Pick                     the old picker (off: rolled for them)
	  FastStart.rollElement(random?)     -> "Fire" | "Frost" (StarterElements)
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
FastStart.Pick = false -- off: no style or element picker (rolled for them)
FastStart.Styles = { "Prospector", "Skirmisher", "Juggernaut" }
FastStart.Elements = { "Fire", "Frost", "Shock", "Poison" }
FastStart.StarterElements = { "Fire", "Frost" } -- Thermal or Cryo, at random
FastStart.DefaultStyle = "Prospector" -- (never shown: everyone starts in it, with sword and shield)

-- A new player's element (Pick off): one of StarterElements at random.
function FastStart.rollElement(random: Random?): string
	local list = FastStart.StarterElements
	return list[(random or Random.new()):NextInteger(1, #list)]
end
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
	E = { "PRESS E: %s", "TAP E: %s", "Your chest gem's move" },
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
