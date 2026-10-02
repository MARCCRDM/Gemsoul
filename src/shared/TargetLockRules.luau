-- Pure selection rules; presentation never grants permission to damage a target.
local Rules = {
	Range = 60,
	AcquireDot = math.cos(math.rad(45)),
	RetainDot = math.cos(math.rad(65)),
	TurnAwayDot = math.cos(math.rad(50)),
	ReleaseDelay = 0.6,
}
function Rules.new()
	return { Target = nil, BlockedUntil = 0 }
end
function Rules.valid(candidate, threshold)
	return candidate.Allowed
		and candidate.Visible
		and candidate.Distance > 0
		and candidate.Distance <= Rules.Range
		and candidate.Facing >= threshold
end
function Rules.update(state, candidates, now, turning)
	if state.Target then
		for _, candidate in candidates do
			if candidate.Target == state.Target and Rules.valid(candidate, Rules.RetainDot) then
				if turning and candidate.Facing < Rules.TurnAwayDot then
					state.Target, state.BlockedUntil = nil, now + Rules.ReleaseDelay
					return nil
				end
				return state.Target
			end
		end
		state.Target = nil
	end
	if now < state.BlockedUntil then
		return nil
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
