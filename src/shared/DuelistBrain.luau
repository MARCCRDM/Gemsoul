--[[
	The PvP Duelist's decisions (pure, so they can be tested): given what it
	sees this moment, what to do next.

	  Stagger   stunned or parried: does nothing
	  Guard     raises its guard against a charging swing (takes 30% damage)
	  Dodge     sidesteps a charging swing (untouchable for a moment)
	  Surge     casts its gem's surge from range (bolt or a ground blast)
	  Retreat   backs off when badly hurt, now and then
	  Approach  closes the distance, weaving side to side
	  Light     a quick swing (short wind-up, may chain a second)
	  Heavy     a slow, telegraphed blow that breaks a raised guard
	  Strafe    circles the player between attacks
]]
local Brain = {}

Brain.Reach = 6.5 -- melee range, studs
Brain.Windup = { Light = 0.35, Heavy = 0.8, Bolt = 0.5, Nova = 1.0 }

export type View = {
	Now: number,
	Distance: number,
	HealthRatio: number,
	Stunned: boolean,
	FoeCharging: boolean, -- the player is winding up a swing
	FoeBlocking: boolean, -- the player's guard is up
	NextAttack: number,
	NextSurge: number,
	NextDefense: number,
	NextRetreat: number,
}

-- `roll` is a random number in [0, 1).
function Brain.decide(v: View, roll: number): string
	if v.Stunned then
		return "Stagger"
	end
	if v.FoeCharging and v.Distance <= Brain.Reach + 3 and v.Now >= v.NextDefense then
		if roll < 0.45 then
			return "Guard"
		elseif roll < 0.75 then
			return "Dodge"
		end
	end
	if v.Now >= v.NextSurge and v.Distance >= 8 and v.Distance <= 32 then
		return "Surge"
	end
	if v.HealthRatio < 0.3 and v.Now >= v.NextRetreat then
		return "Retreat"
	end
	if v.Distance > Brain.Reach then
		return "Approach"
	end
	if v.Now >= v.NextAttack then
		-- A raised guard invites a guard-breaking heavy.
		if v.FoeBlocking then
			return if roll < 0.7 then "Heavy" else "Light"
		end
		return if roll < 0.3 then "Heavy" else "Light"
	end
	return "Strafe"
end

return Brain
