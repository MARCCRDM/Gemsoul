-- Pure selection rules; presentation never grants permission to damage a target.
-- The lock is automatic and goes for the nearest enemy:
--   * with no target, it takes whatever is attacking you (nearest first,
--     wherever it is), else the nearest enemy ahead of you, else your Arena
--     rival wherever it is
--   * with a target, it moves to any enemy that gets nearer than it by
--     SwitchMargin studs, as long as that one is in sight or attacking you
--   * the target holds through turning, mouse and touch look, and up to
--     HiddenGrace seconds of cover; it lets go when the target dies, leaves
--     RetainRange or stays hidden. Your rival is never let go for distance
--     or cover, only when it dies or becomes ineligible
--   * with several targets within SwitchRange, Rules.switch cycles through
--     them left to right; a target you switched to is kept until it's lost
--   * Rules.pick locks a target chosen directly (the target list), pinned
--     the same way
local Rules = {
	Range = 90, -- picking up a new target in front of you
	RetainRange = 140, -- keeping an ordinary one
	AcquireDot = math.cos(math.rad(45)),
	HiddenGrace = 4,
	SwitchRange = 10, -- studs: the targets around you that switching cycles through
	SwitchMargin = 2, -- studs: how much nearer another enemy must be to take the lock
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
-- hidden longer than HiddenGrace). The rival is held at any range, in cover.
local function keep(state, candidates, now)
	for _, candidate in candidates do
		if candidate.Target == state.Target then
			if candidate.Priority and candidate.Allowed then
				state.HiddenSince = nil
				return true
			end
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
-- Locks a chosen target (tapped in the target list); it stays there
-- (pinned) like a switch. Only a target that could be held is taken.
function Rules.pick(state, candidates, model)
	for _, candidate in candidates do
		if candidate.Target == model and holdable(candidate) then
			state.Target, state.HiddenSince, state.Pinned = model, nil, true
			return model
		end
	end
	return state.Target
end
-- The nearest enemy that can take the lock from a current target: in range
-- and in sight, or attacking you.
local function nearestRival(candidates, exclude)
	local best
	for _, candidate in candidates do
		if
			candidate.Target ~= exclude
			and candidate.Allowed
			and candidate.Distance > 0
			and candidate.Distance <= Rules.Range
			and (candidate.Visible or candidate.Engaged)
			and (not best or candidate.Distance < best.Distance)
		then
			best = candidate
		end
	end
	return best
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
	state.Priority = false
	if state.Target and keep(state, candidates, now) then
		-- Held, unless another enemy is clearly nearer.
		local current
		for _, candidate in candidates do
			if candidate.Target == state.Target then
				current = candidate
			end
		end
		local nearer = nearestRival(candidates, state.Target)
		if nearer and nearer.Distance < current.Distance - Rules.SwitchMargin then
			state.Target, state.HiddenSince = nearer.Target, nil
		end
		return state.Target
	end
	state.Target, state.HiddenSince = nil, nil
	-- Whatever is attacking you, nearest first, wherever it is.
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
	-- The nearest enemy ahead of you.
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
	if closest then
		state.Target = closest.Target
		return state.Target
	end
	-- Your Arena rival, wherever it is.
	for _, candidate in candidates do
		if candidate.Priority and candidate.Allowed then
			state.Target = candidate.Target
			return state.Target
		end
	end
	return nil
end
return Rules
