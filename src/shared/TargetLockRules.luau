-- Pure selection rules; presentation never grants permission to damage a target.
-- The lock is sticky and automatic:
--   * a priority target (your Arena rival) is taken the moment it's there,
--     from any angle, and never let go for distance or cover, only when it
--     dies or becomes ineligible
--   * anything that engages you (hits you) is locked at once if you have no
--     target, wherever it is
--   * any other lock holds through turning, mouse and touch look, and up to
--     HiddenGrace seconds of cover; it lets go when the target dies, leaves
--     RetainRange or stays hidden
local Rules = {
	Range = 90, -- picking up a new target in front of you
	RetainRange = 140, -- keeping an ordinary one
	AcquireDot = math.cos(math.rad(45)),
	HiddenGrace = 4,
}
function Rules.new()
	return { Target = nil, HiddenSince = nil, Priority = false }
end
-- Can this candidate be picked up as a new target?
function Rules.valid(candidate, threshold)
	return candidate.Allowed
		and candidate.Visible
		and candidate.Distance > 0
		and candidate.Distance <= Rules.Range
		and (candidate.Priority == true or candidate.Facing >= threshold)
end
local function holdable(candidate)
	return candidate.Allowed and candidate.Distance > 0 and candidate.Distance <= Rules.RetainRange
end
-- `_turning` is kept for callers; turning never breaks the lock.
function Rules.update(state, candidates, now, _turning)
	-- Your rival takes the lock from anything else, and keeps it.
	for _, candidate in candidates do
		if candidate.Priority and candidate.Allowed then
			if state.Target ~= candidate.Target then
				state.Target, state.HiddenSince = candidate.Target, nil
			end
			state.Priority = true
			return state.Target
		end
	end
	state.Priority = false
	if state.Target then
		for _, candidate in candidates do
			if candidate.Target == state.Target then
				if holdable(candidate) then
					if candidate.Visible then
						state.HiddenSince = nil
						return state.Target
					end
					state.HiddenSince = state.HiddenSince or now
					if now - state.HiddenSince < Rules.HiddenGrace then
						return state.Target
					end
				end
				break
			end
		end
		state.Target, state.HiddenSince = nil, nil
	end
	-- Whatever is attacking you, wherever it is.
	local engaged
	for _, candidate in candidates do
		if candidate.Engaged and holdable(candidate) and (not engaged or candidate.Distance < engaged.Distance) then
			engaged = candidate
		end
	end
	if engaged then
		state.Target = engaged.Target
		return state.Target
	end
	local closest
	for _, candidate in candidates do
		if
			Rules.valid(candidate, Rules.AcquireDot)
			and (
				not closest
				or candidate.Distance < closest.Distance
				or (candidate.Distance == closest.Distance and candidate.Facing > closest.Facing)
			)
		then
			closest = candidate
		end
	end
	state.Target = closest and closest.Target or nil
	return state.Target
end
return Rules
