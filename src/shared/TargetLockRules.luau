-- Pure selection rules; presentation never grants permission to damage a target.
-- The lock is sticky: once on a target it holds through turning, mouse and
-- touch look, and brief cover (up to HiddenGrace seconds out of sight). It
-- only lets go when the target dies or becomes ineligible, leaves
-- RetainRange, or stays hidden. A priority target (your Arena rival) is
-- taken from any angle and always wins the lock.
local Rules = {
	Range = 90, -- picking up a new target
	RetainRange = 140, -- keeping one
	AcquireDot = math.cos(math.rad(45)),
	HiddenGrace = 1.5,
}
function Rules.new()
	return { Target = nil, HiddenSince = nil }
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
-- `_turning` is kept for callers; turning no longer breaks the lock.
function Rules.update(state, candidates, now, _turning)
	-- Your rival takes the lock from anything else.
	for _, candidate in candidates do
		if candidate.Priority and holdable(candidate) and state.Target ~= candidate.Target then
			state.Target, state.HiddenSince = candidate.Target, nil
			return state.Target
		end
	end
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
