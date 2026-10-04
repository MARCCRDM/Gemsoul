--[[
	Who an enemy (a monster, or a raid boss) goes after. Pure rules, shared by
	Enemies and the raid boss in Duelist.

	Threat is what each player has done to it: damage dealt (times the
	player's Threat Generation), plus a spike for stunning or interrupting it.
	Threat fades once a player stops attacking (FadeAfter, then FadePerSecond),
	so a player who hit hard a minute ago doesn't hold it forever.

	Choosing, in order:
	  1. A taunt holds it (the caller handles taunts before asking).
	  2. Its target is lost (down, gone, out of reach or leash): the player
	     with the most threat, or the nearest one when nobody has any.
	  3. It holds a new target at least HoldSeconds, so it doesn't flicker.
	  4. Someone else's threat overtakes the target's: by 10% when they're
	     within its reach (in its face), by 30% from further away (WoW's rule).
	  5. Smelling blood: a player under LowHealth counts LowHealthBonus times
	     their threat, so it turns to finish off a weakened player.
	  6. Out of reach: when its target has been out of its reach for
	     UnreachableSeconds, it settles for the nearest player it can hit.
]]
local Aggro = {
	MeleeOvertake = 1.1,
	RangedOvertake = 1.3,
	HoldSeconds = 1.5,
	FadeAfter = 6, -- seconds without hitting before a player's threat fades
	FadePerSecond = 0.12, -- the share of threat lost each second after that
	LowHealth = 0.25,
	LowHealthBonus = 1.3,
	ControlThreat = 0.12, -- a stun or interrupt: this share of its max health as threat
	UnreachableSeconds = 4,
}

export type Candidate = {
	Key: any, -- the player
	Threat: number,
	Distance: number,
	InReach: boolean, -- close enough for it to hit them now
	HealthRatio: number, -- 0..1
}

export type State = { Target: any?, Since: number, OutOfReachSince: number? }

function Aggro.new(): State
	return { Target = nil, Since = -math.huge, OutOfReachSince = nil }
end

-- Threat as it counts when choosing (with the low-health pull).
function Aggro.effective(candidate: Candidate): number
	local threat = candidate.Threat
	if candidate.HealthRatio <= Aggro.LowHealth then
		threat *= Aggro.LowHealthBonus
	end
	return threat
end

-- Adds threat for `key` (damage, or a stun or interrupt), noting when.
function Aggro.add(threat: { [any]: number }, hitAt: { [any]: number }, key: any, amount: number, now: number)
	threat[key] = (threat[key] or 0) + math.max(0, amount)
	hitAt[key] = now
end

-- Fades the threat of anyone who hasn't hit it for FadeAfter seconds.
function Aggro.fade(threat: { [any]: number }, hitAt: { [any]: number }, dt: number, now: number)
	for key, value in threat do
		if now - (hitAt[key] or -math.huge) > Aggro.FadeAfter then
			local faded = value * math.max(0, 1 - Aggro.FadePerSecond * dt)
			threat[key] = if faded < 0.5 then nil else faded
		end
	end
end

local function nearest(candidates: { Candidate }, onlyInReach: boolean): Candidate?
	local best
	for _, c in candidates do
		if (not onlyInReach or c.InReach) and (not best or c.Distance < best.Distance) then
			best = c
		end
	end
	return best
end

local function switch(state: State, candidate: Candidate?, now: number): any?
	local key = candidate and candidate.Key
	if key ~= state.Target then
		state.Target, state.Since = key, now
		state.OutOfReachSince = if candidate and not candidate.InReach then now else nil
	end
	return state.Target
end

-- The player it should be attacking now, from the players it can see and
-- chase (`candidates`), or nil when there are none.
function Aggro.choose(state: State, candidates: { Candidate }, now: number): any?
	local current, top
	for _, c in candidates do
		if c.Key == state.Target then
			current = c
		end
		if not top or Aggro.effective(c) > Aggro.effective(top) then
			top = c
		end
	end
	if not top then
		return switch(state, nil, now)
	end
	-- Lost its target: the biggest threat, or the nearest if nobody has any.
	if not current then
		return switch(state, if Aggro.effective(top) > 0 then top else nearest(candidates, false), now)
	end
	-- Can't reach its target for a while: take the nearest it can hit.
	if current.InReach then
		state.OutOfReachSince = nil
	else
		state.OutOfReachSince = state.OutOfReachSince or now
		if now - state.OutOfReachSince >= Aggro.UnreachableSeconds then
			local reachable = nearest(candidates, true)
			if reachable then
				return switch(state, reachable, now)
			end
		end
	end
	if now - state.Since < Aggro.HoldSeconds or top == current then
		return state.Target
	end
	-- Overtaken: by 10% up close, by 30% from range.
	local needed = Aggro.effective(current) * (if top.InReach then Aggro.MeleeOvertake else Aggro.RangedOvertake)
	if Aggro.effective(top) > needed then
		return switch(state, top, now)
	end
	return state.Target
end

return Aggro
