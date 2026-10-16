-- Rig Maneuvers retired (Tech.ManeuversEnabled off, the live setting): the
-- tree opens on Passive Augments, with no Rig Maneuvers tab.
local count = 0
local function check(ok, message)
	count += 1
	assert(ok, message)
end
local function cards()
	local total = 0
	for _, o in objects do
		if not o.Destroyed and o.ClassName == "TextButton" and o["@AugmentNode"] then
			total += 1
		end
	end
	return total
end
local function tab(name)
	for _, o in objects do
		if not o.Destroyed and o.ClassName == "TextLabel" and o.Text == name and o.Parent.ClassName == "TextButton" then
			return o.Parent
		end
	end
	return nil
end
UI.open()
check(UI.isOpen() and cards() == #Tree.Order.PassiveAugments, "The tree didn't open on Passive Augments")
for _, o in objects do
	if not o.Destroyed and o.ClassName == "TextButton" and o["@AugmentNode"] then
		check(Tree.Nodes[o["@AugmentNode"]].Branch ~= "RigManeuvers", "A retired maneuver was shown")
	end
end
check(tab("Rig Maneuvers") == nil, "The retired Rig Maneuvers tab is still there")
check(tab("Surge Amplifiers") and tab("Passive Augments"), "Branch tabs missing")
tab("Surge Amplifiers").Activated.Fire()
check(cards() == #Tree.Order.SurgeAmplifiers, "Surge Amplifiers tab missing nodes")
UI.close()
check(not UI.isOpen(), "Tree failed to close")
print(
	"PASS: "
		.. count
		.. " Augment Tree UI checks with Rig Maneuvers retired (opens on Passive Augments, no maneuver tab)"
)
