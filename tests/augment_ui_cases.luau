local count = 0
local function check(ok, message) count += 1; assert(ok, message) end
local function find(class, match)
	for _, object in objects do
		if not object.Destroyed and object.ClassName == class and match(object) then return object end
	end
	error("UI object missing: " .. class)
end
local function card(name)
	return find("TextLabel", function(o) return o.Text and string.find(o.Text, name, 1, true) and o.Parent.ClassName == "TextButton" end).Parent
end
local function cards()
	local total = 0
	for _, o in objects do
		if not o.Destroyed and o.ClassName == "TextButton" and o.Size and o.Size.Y.Offset == 112 then total += 1 end
	end
	return total
end
local function tab(name)
	return find("TextLabel", function(o) return o.Text == name and o.Parent.ClassName == "TextButton" end).Parent
end
local function label(text)
	return find("TextLabel", function(o) return o.Text == text end)
end
local gui = find("ScreenGui", function(o) return o.Name == "AugmentTree" end)
check(not UI.isOpen() and not gui.Enabled, "Tree opened on boot")
UI.open()
check(UI.isOpen() and cards() == 6, "Tree did not show one branch of six connected nodes")
check(tab("Rig Maneuvers") and tab("Gem Surges") and tab("Passive Augments"), "Branch tabs missing")
check(label("1/6") ~= nil, "Branch progress missing")
local unlock = find("TextButton", function(o) return o.Text and string.find(o.Text, "UNLOCKED", 1, true) end)
check(unlock.Active == false, "Starter node can be bought twice")
local reset = find("TextButton", function(o) return o.Text == "Nothing to refund yet" end)
check(reset.Active == false, "Nothing spent, yet refund is offered")
card("Armor Piercer").Activated.Fire()
check(unlock.Active == false and string.find(unlock.Text, "PREREQUISITE LOCKED", 1, true), "Locked node has invalid unlock state")
card("Servo Flurry").Activated.Fire()
check(unlock.Active == true and string.find(unlock.Text, "1 POINT", 1, true), "Eligible node cannot be unlocked")
unlock.Activated.Fire()
check(GemClient.Profile.Augments.Unlocked.ServoFlurry and GemClient.Profile.Augments.Points == 2 and unlock.Active == false, "Unlock UI did not update saved state")
check(label("2/6") ~= nil and label("2") ~= nil, "Branch progress or points did not update")
check(reset.Active and string.find(reset.Text, "1 point", 1, true), "Spent points cannot be refunded")
player.attributes.CombatSession = "PvP"
player.events.CombatSession.Fire()
check(reset.Active == false, "UI permits reset during Arena session")
player.attributes.CombatSession = nil
player.events.CombatSession.Fire()
reset.Activated.Fire()
check(not GemClient.Profile.Augments.Unlocked.ServoFlurry and GemClient.Profile.Augments.Points == 3, "UI reset failed to refund")
tab("Gem Surges").Activated.Fire()
check(cards() == 6 and card("Cryo Lance") ~= nil, "Branch tab failed")
card("Cryo Shield").Activated.Fire()
check(unlock.Active == false and string.find(unlock.Text, "PREREQUISITE LOCKED", 1, true), "Surge prerequisites ignored by UI")
tab("Passive Augments").Activated.Fire()
check(cards() == 6 and card("Blade Calibration") ~= nil, "Passive branch tab failed")
card("Blade Calibration").Activated.Fire()
check(unlock.Active == true and label("SWORD DAMAGE") ~= nil, "Passive node details missing")
UI.close()
check(not UI.isOpen(), "Tree failed to close")
UI.toggle()
check(UI.isOpen(), "Tree toggle failed")
print("PASS: " .. count .. " real Augment Tree UI checks (branch tabs and progress, locked nodes, unlocks, refunds, combat lock and modal lifecycle)")
