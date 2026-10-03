--[[
	The PvP Duelist's decisions (pure, so they can be tested): given what it
	sees this moment, what to do next. It plays aggressively and reads the
	player:

	  Stagger   stunned or parried: does nothing
	  Riposte   a counter-swing straight after blocking one of yours
	  Guard     raises its guard against your swings (most of the time, and
	            longer when you're pressing it); a hit that lands just as
	            it raises it is parried
	  Dodge     sidesteps a charged heavy (which would break its guard) or a
	            surge wind-up, and anything once its guard is broken
	  GuardAdvance  walks you down shield-first (from mid range, or under fire)
	  Punish    a fast counter-swing while the player recovers from an attack
	  Surge     casts its gem's surge: from range, or point-blank when the
	            player is stunned, slowed or hiding behind their guard
	  Retreat   backs off briefly when badly hurt (never when the player is low)
	  Lunge     dashes in from mid range and swings straight away
	  Approach  closes the distance
	  Light     a quick swing (may chain into a combo)
	  Heavy     a slow, telegraphed blow that breaks a raised guard
	  Strafe    circles the player between attacks
]]
local Brain = {}

Brain.Reach = 6.5 -- melee range, studs
-- Wind-ups, seconds. Bolts, blasts and heavies are slow enough to see on the
-- enemy cast bar and dodge (tap Space to hop aside, double-tap to roll).
Brain.Windup = { Light = 0.3, Heavy = 0.75, Punish = 0.18, Lunge = 0.25, Bolt = 0.7, Nova = 1.05 } -- (a blast's ring is wide: a moment more to get out)
Brain.BoltRadius = 3.5 -- a bolt hits within this many studs of where it was aimed
Brain.SurgeRange = 32
Brain.LungeRange = 18
Brain.IdleAfter = 1.2 -- seconds of you doing nothing before it presses the attack
Brain.MaxLull = 1.6 -- the longest it goes without attacking while you're in reach

export type View = {
	Now: number,
	Distance: number,
	HealthRatio: number,
	Stunned: boolean,
	FoeCharging: boolean, -- winding up a swing
	FoeHeavy: boolean?, -- held long enough to be a heavy (breaks a guard)
	FoeAttacking: boolean?, -- swung in the last half second (mid-combo)
	FoeAggressive: boolean?, -- two or more swings in the last few seconds
	FoeRanged: boolean?, -- fights with a gun
	GuardBroken: boolean?, -- its guard was just broken: can't raise it
	JustBlocked: boolean?, -- just blocked one of your swings
	Guarding: boolean?, -- its guard is up right now
	FoeCasting: boolean, -- winding up a surge or maneuver
	FoeBlocking: boolean, -- guard up
	FoeRecovering: boolean, -- just attacked and can't act yet
	FoeVulnerable: boolean, -- stunned or slowed
	FoeLow: boolean, -- below 30% health
	FoeIdle: boolean?, -- not swinging, blocking, casting or charging for a while: press the attack
	SinceOffense: number?, -- seconds since it last attacked or cast
	NextAttack: number,
	NextSurge: number,
	NextDefense: number,
	NextRetreat: number,
	NextLunge: number,
}

-- A bolt aimed at `aim` hits a player now at `at` (only sideways distance counts).
function Brain.boltHits(aim: Vector3, at: Vector3): boolean
	local offset = at - aim
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Brain.BoltRadius
end

-- `roll` is a random number in [0, 1).
function Brain.decide(v: View, roll: number): string
	if v.Stunned then
		return "Stagger"
	end
	-- Blocked your swing: hit back while you're open.
	-- (Most of the time; otherwise it stays behind the shield.)
	if v.JustBlocked and v.Distance <= Brain.Reach + 1.5 and (roll < 0.7 or not v.FoeAttacking) then
		return "Riposte"
	end
	-- Shield already up and you're still swinging: hold it (a heavy is
	-- dodged instead, below). It answers once a swing is blocked.
	if v.Guarding and (v.FoeAttacking or v.FoeCharging) and not v.FoeHeavy then
		return "Guard"
	end
	-- Defend against what's coming, but not every time (it reads, not cheats).
	local threat = v.FoeCharging or v.FoeCasting or v.FoeAttacking
	if threat and v.Distance <= Brain.Reach + 4 and v.Now >= v.NextDefense then
		if v.FoeHeavy or v.GuardBroken then
			-- A heavy would break the guard: get out of the way instead.
			if roll < 0.75 then
				return "Dodge"
			end
		elseif v.FoeCasting and not v.FoeCharging then
			if roll < 0.45 then
				return "Guard"
			elseif roll < 0.85 then
				return "Dodge"
			end
		else
			-- Quick swings: shield up nearly always, more so against a flurry.
			local guard = if v.FoeAggressive then 0.92 else 0.85
			if roll < guard then
				return "Guard"
			elseif roll < 0.97 then
				return "Dodge"
			end
		end
	end
	-- Facing a gun: close in behind the shield.
	if v.FoeRanged and v.Distance > Brain.Reach + 2 and not v.GuardBroken then
		if v.FoeRecovering or roll < 0.8 then
			return "GuardAdvance"
		end
	end
	-- Never stalls: too long without attacking and it swings as soon as it
	-- can, whatever you're doing.
	if (v.SinceOffense or 0) > Brain.MaxLull and v.Distance <= Brain.Reach + 1 and v.Now >= v.NextAttack then
		return if roll < 0.3 then "Heavy" else "Light"
	end
	-- An opening: hit the player while they recover.
	if v.FoeRecovering and v.Distance <= Brain.Reach + 2 then
		return "Punish"
	end
	if v.Now >= v.NextSurge and v.Distance <= Brain.SurgeRange then
		if v.Distance >= 8 or v.FoeVulnerable or v.FoeBlocking or v.FoeIdle then
			return "Surge"
		end
	end
	if v.HealthRatio < 0.25 and not v.FoeLow and v.Now >= v.NextRetreat then
		return "Retreat"
	end
	if v.Distance > Brain.Reach + 2 and v.Distance <= Brain.LungeRange and v.Now >= v.NextLunge then
		return "Lunge"
	end
	if v.Distance > Brain.Reach then
		-- Mid range: walk you down behind the shield; from far, or when
		-- you're standing idle, run straight in.
		if v.Distance <= Brain.LungeRange + 6 and not v.GuardBroken and not v.FoeIdle then
			return "GuardAdvance"
		end
		return "Approach"
	end
	if v.Now >= v.NextAttack then
		if v.FoeBlocking then
			return if roll < 0.7 then "Heavy" else "Light"
		end
		if v.FoeLow then
			return if roll < 0.15 then "Heavy" else "Light" -- quick pressure to finish
		end
		-- An idle foe is a free target: more heavies.
		return if roll < (if v.FoeIdle then 0.4 else 0.25) then "Heavy" else "Light"
	end
	-- Waiting on its next swing up close: shield up rather than open, unless
	-- you're doing nothing (then it stays on you, ready to swing).
	if v.Distance <= Brain.Reach + 3 and not v.GuardBroken and not v.FoeIdle and roll < 0.6 then
		return "Guard"
	end
	return "Strafe"
end

-- Which ready surge suits this moment, or nil. Surges are
-- { Kind = "Bolt" | "Nova" | "Self", SelfCentered, Radius, Power, Next }.
function Brain.pickSurge(surges, now: number, distance: number, v: View)
	local best, bestScore = nil, 0
	for _, surge in surges do
		if now >= surge.Next then
			local score = 0
			if surge.Kind == "Self" then
				-- Shields, heals and buffs: when hurt or in the thick of it.
				score = if v.HealthRatio < 0.7 or distance <= Brain.Reach then 3 else 0
			elseif surge.Kind == "Nova" then
				if surge.SelfCentered then
					score = if distance <= surge.Radius then 4 else 0
				else
					-- Blasts land best on a target that can't step away.
					score = if v.FoeVulnerable or v.FoeBlocking then 5 else 2
				end
			else
				score = if distance >= 8 then 4 else 1 -- bolts from range
			end
			if score > 0 then
				score += surge.Power
				if score > bestScore then
					best, bestScore = surge, score
				end
			end
		end
	end
	return best
end

-- Swaps a basic action for one of its Rig Maneuvers (keys 1, 2, 3) when one
-- fits, as a player would. Moves are { Id, Power, Windup?, Next }.
function Brain.pickMove(moves, choice: string, now: number, distance: number, roll: number)
	local function ready(id: string)
		for _, move in moves do
			if move.Id == id and now >= move.Next then
				return move
			end
		end
		return nil
	end
	if choice == "Dodge" then
		return ready("StimDodge") -- a dodge that also heals
	elseif choice == "Lunge" then
		return ready("ThrusterLeap") or ready("KineticRam") -- close the gap
	elseif choice == "Interrupt" then
		-- Jab a cast in progress, if in reach.
		return if distance <= Brain.Reach + 1 then ready("PneumaticJab") else nil
	elseif choice == "Guard" and roll < 0.3 then
		return ready("RiposteStance") -- sometimes brace to turn the blow aside
	elseif
		(choice == "Light" or choice == "Heavy" or choice == "Punish")
		and distance <= Brain.Reach
		and roll < 0.4
	then
		-- The strongest ready strike; slow wind-up ones only in place of a heavy.
		local best = nil
		for _, move in moves do
			if
				now >= move.Next
				and move.Id ~= "StimDodge"
				and move.Id ~= "RiposteStance"
				and move.Id ~= "PneumaticJab"
				and (choice == "Heavy" or not move.Windup)
				and (not best or move.Power > best.Power)
			then
				best = move
			end
		end
		return best
	end
	return nil
end

return Brain
