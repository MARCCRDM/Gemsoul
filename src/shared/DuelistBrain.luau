--[[
	The PvP Duelist's decisions (pure, so they can be tested): given what it
	sees this moment, what to do next. It plays aggressively and reads the
	player:

	  Stagger   stunned or parried: does nothing
	  Guard     raises its guard against a charging swing or a surge wind-up
	  Dodge     sidesteps a charging swing or a surge wind-up
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
Brain.Windup = { Light = 0.3, Heavy = 0.75, Punish = 0.18, Lunge = 0.25, Bolt = 0.45, Nova = 0.9 }
Brain.SurgeRange = 32
Brain.LungeRange = 18

export type View = {
	Now: number,
	Distance: number,
	HealthRatio: number,
	Stunned: boolean,
	FoeCharging: boolean, -- winding up a swing
	FoeCasting: boolean, -- winding up a surge or maneuver
	FoeBlocking: boolean, -- guard up
	FoeRecovering: boolean, -- just attacked and can't act yet
	FoeVulnerable: boolean, -- stunned or slowed
	FoeLow: boolean, -- below 30% health
	NextAttack: number,
	NextSurge: number,
	NextDefense: number,
	NextRetreat: number,
	NextLunge: number,
}

-- `roll` is a random number in [0, 1).
function Brain.decide(v: View, roll: number): string
	if v.Stunned then
		return "Stagger"
	end
	-- Defend against what's coming, but not every time (it reads, not cheats).
	if (v.FoeCharging or v.FoeCasting) and v.Distance <= Brain.Reach + 4 and v.Now >= v.NextDefense then
		if roll < 0.4 then
			return "Guard"
		elseif roll < 0.8 then
			return "Dodge"
		end
	end
	-- An opening: hit the player while they recover.
	if v.FoeRecovering and v.Distance <= Brain.Reach + 2 then
		return "Punish"
	end
	if v.Now >= v.NextSurge and v.Distance <= Brain.SurgeRange then
		if v.Distance >= 8 or v.FoeVulnerable or v.FoeBlocking then
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
		return "Approach"
	end
	if v.Now >= v.NextAttack then
		if v.FoeBlocking then
			return if roll < 0.7 then "Heavy" else "Light"
		end
		if v.FoeLow then
			return if roll < 0.15 then "Heavy" else "Light" -- quick pressure to finish
		end
		return if roll < 0.25 then "Heavy" else "Light"
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

return Brain
