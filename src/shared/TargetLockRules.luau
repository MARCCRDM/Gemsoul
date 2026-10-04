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
--   * with several targets within SwitchRange, Rules.switch cycles through
--     them left to right; a target you switched to is kept like any other
--     lock and wins over the rival and attackers until it's lost
local Rules = {
	Range = 90, -- picking up a new target in front of you
	RetainRange = 140, -- keeping an ordinary one
	AcquireDot = math.cos(math.rad(45)),
	HiddenGrace = 4,
	SwitchRange = 10, -- studs: the targets around you that switching cycles through
}
function Rules.new()
	return { Target = nil, HiddenSince = nil, Priority = false, Pinned = false }
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
-- Keeps the current target if it can still be held (in range, and not
-- hidden longer than HiddenGrace).
local function keep(state, candidates, now)
	for _, candidate in candidates do
		if candidate.Target == state.Target then
			if holdable(candidate) then
				if candidate.Visible then
					state.HiddenSince = nil
					return true
				end
				state.HiddenSince = state.HiddenSince or now
				return now - state.HiddenSince < Rules.HiddenGrace
			end
			return false
		end
	end
	return false
end
-- The targets that switching cycles through, left to right (by Bearing).
function Rules.switchable(candidates)
	local nearby = {}
	for _, candidate in candidates do
		if candidate.Allowed and candidate.Distance > 0 and candidate.Distance <= Rules.SwitchRange then
			table.insert(nearby, candidate)
		end
	end
	table.sort(nearby, function(a, b)
		return (a.Bearing or 0) < (b.Bearing or 0)
	end)
	return nearby
end
-- Moves the lock to the next target around you; it stays there (pinned).
function Rules.switch(state, candidates)
	local nearby = Rules.switchable(candidates)
	if #nearby == 0 then
		return state.Target
	end
	local index = 0
	for i, candidate in nearby do
		if candidate.Target == state.Target then
			index = i
		end
	end
	local pick = nearby[index % #nearby + 1]
	state.Target, state.HiddenSince, state.Pinned = pick.Target, nil, true
	return state.Target
end
-- `_turning` is kept for callers; turning never breaks the lock.
function Rules.update(state, candidates, now, _turning)
	-- A target you switched to holds until it's lost.
	if state.Pinned then
		if state.Target and keep(state, candidates, now) then
			return state.Target
		end
		state.Target, state.HiddenSince, state.Pinned = nil, nil, false
	end
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
		if keep(state, candidates, now) then
			return state.Target
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
