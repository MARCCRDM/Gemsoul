--[[
	A new miner's first steps, after the first fight: one NEXT STEP card on
	the play screen (Client FirstSteps) until they've done them, in order:

	  Mine     break a glowing rock (every rock holds a gem)
	  Socket   put that gem in your gear (its button does it: EQUIP BEST)
	  Surge    put a gem in Q, E or R, when one would be stronger there
	           (its button does it: UPGRADE SURGES)
	  Duel     play another duel, to feel what the gems do (PLAY)

	These are the onboarding funnel's steps 7 to 11 (Server.Funnel), where
	new players were dropping: half of those who found a gem never socketed
	it. Only for accounts the funnel counts (profile.Funnel, made on a new
	account's first load), once their intro is done; never again once done.

	Pure, for the client and tests.

	  FirstSteps.Steps                       in order: Id, Title, Line, Mobile?, Button
	  FirstSteps.view(profile, extra) -> view
	      extra: { Duels = DuelsPlayed attribute, SocketOpen = a gem would go
	      in your gear (UpgradeHints .Equipment), SurgeOpen = one would be
	      stronger in Q/E/R (UpgradeHints .Surges.Changes > 0) }
	  FirstSteps.current(view) -> step?, index, total   nil: nothing to coach
]]
local FirstSteps = {}

FirstSteps.Steps = {
	{
		Id = "Mine",
		Title = "BREAK A GLOWING ROCK",
		Line = "Walk up to one and swing: click it or press E.",
		Mobile = "Walk up to one and tap to swing.",
		Button = "HOW?",
	},
	{
		Id = "Socket",
		Title = "SOCKET YOUR GEM",
		Line = "A gem in your gear makes you stronger.",
		Button = "SOCKET IT",
	},
	{
		Id = "Surge",
		Title = "READY A SURGE",
		Line = "A gem in Q, E or R is a power you cast.",
		Button = "SET IT",
	},
	{
		Id = "Duel",
		Title = "TRY YOUR GEMS IN A DUEL",
		Line = "See what your new power does.",
		Button = "PLAY",
	},
}

function FirstSteps.view(profile, extra)
	extra = extra or {}
	local counts = profile and profile.TrainingRewards and profile.TrainingRewards.Counts or {}
	local funnel = profile and profile.Funnel
	return {
		New = type(funnel) == "table",
		IntroDone = profile ~= nil and profile.Intro ~= nil and profile.Intro.Done == true,
		Mined = (counts.Mine or 0) >= 1 or (counts.MineGem or 0) >= 1 or (type(funnel) == "table" and funnel["First rock"] == true),
		Socketed = (counts.Enchant or 0) >= 1 or (type(funnel) == "table" and funnel.Socketed == true),
		Surged = (counts.EquipSurge or 0) >= 1 or (type(funnel) == "table" and funnel["Surge ready"] == true),
		Dueled = (type(extra.Duels) == "number" and extra.Duels >= 2) or (type(funnel) == "table" and funnel["Second duel"] == true),
		SocketOpen = extra.SocketOpen == true,
		SurgeOpen = extra.SurgeOpen == true,
	}
end

-- The step to show now. Socket and Surge wait for something to put in
-- (skipped when there's nothing better to socket); Duel comes last.
function FirstSteps.current(view)
	local total = #FirstSteps.Steps
	if not view or not view.New or not view.IntroDone or view.Dueled then
		return nil, 0, total
	end
	if not view.Mined then
		return FirstSteps.Steps[1], 1, total
	end
	if not view.Socketed and view.SocketOpen then
		return FirstSteps.Steps[2], 2, total
	end
	if not view.Surged and view.SurgeOpen then
		return FirstSteps.Steps[3], 3, total
	end
	return FirstSteps.Steps[4], 4, total
end

return FirstSteps
