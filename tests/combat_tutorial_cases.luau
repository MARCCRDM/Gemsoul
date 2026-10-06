-- Combat training's lessons (Shared.CombatTutorial).
do
	local checks = 0
	local function check(value, message)
		checks += 1
		assert(value, message)
	end
	local ids, events = {}, { Hit = true, Heavy = true, Block = true, Dodge = true, Surge = true, Win = true }
	local partners = { Stand = true, Swing = true, HeavyBlow = true, Fight = true }
	local targets = { Basic = true, Heavy = true, Block = true, Dodge = true, Surge = true }
	for i, step in CombatTutorial.Steps do
		check(not ids[step.Id], "Duplicate lesson " .. step.Id)
		ids[step.Id] = true
		check(events[step.Event], step.Id .. " counts an unknown event")
		check(partners[step.Partner], step.Id .. " has an unknown partner behaviour")
		check(step.Highlight == nil or targets[step.Highlight], step.Id .. " points at an unknown control")
		check(type(step.Goal) == "number" and step.Goal >= 1, step.Id .. " has no goal")
		check(#CombatTutorial.text(step, false) > 10 and #CombatTutorial.text(step, true) > 10, step.Id .. " lacks text")
		check(CombatTutorial.step(i) == step, "Lesson lookup broken")
	end
	-- What a new player has to learn: attack, heavy, block, dodge, surges, then a real spar.
	for _, id in { "Attack", "Heavy", "Block", "Dodge", "Surge", "Spar" } do
		check(ids[id], "Combat training lacks the " .. id .. " lesson")
	end
	local last = CombatTutorial.Steps[CombatTutorial.count()]
	check(last.Event == "Win" and last.Partner == "Fight", "Training doesn't end in a real spar")
	for i = 1, CombatTutorial.count() - 1 do
		check(CombatTutorial.Steps[i].Partner ~= "Fight", "A lesson before the spar fights for real")
	end
	-- Touch players are told about buttons, mouse players about the mouse.
	check(string.find(CombatTutorial.text(CombatTutorial.step(1), true), "ATTACK"), "Touch text doesn't name the button")
	check(string.find(CombatTutorial.text(CombatTutorial.step(1), false), "MOUSE"), "Keys text doesn't name the mouse")
	-- Lessons the player can't do (no surge equipped) are skipped.
	local surge
	for i, step in CombatTutorial.Steps do
		if step.Event == "Surge" then
			surge = i
		end
	end
	check(CombatTutorial.nextStep(surge - 1) == surge, "Surge lesson skipped when it shouldn't be")
	check(CombatTutorial.nextStep(surge - 1, function(step)
		return step.Event ~= "Surge"
	end) == surge + 1, "Surge lesson not skipped without surges")
	check(CombatTutorial.nextStep(CombatTutorial.count()) == nil, "A lesson after the last")
	print("PASS: " .. checks .. " combat training lesson checks")
end
