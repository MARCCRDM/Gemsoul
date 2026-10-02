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
		if not o.Destroyed and o.ClassName == "TextButton" and o.Size and o.Size.Y.Offset == 88 then total += 1 end
	end
	return total
end
local gui = find("ScreenGui", function(o) return o.Name == "AugmentTree" end)
check(not UI.isOpen() and not gui.Enabled, "Tree opened on boot")
UI.open()
check(UI.isOpen() and cards() == 18, "Desktop did not display all three connected branches")
local unlock = find("TextButton", function(o) return o.Text == "UNLOCKED" end)
check(unlock.Active == false, "Starter node can be bought twice")
card("Armor Piercer").Activated.Fire()
check(unlock.Active == false and unlock.Text == "PREREQUISITE LOCKED", "Locked node has invalid unlock state")
card("Servo Flurry").Activated.Fire()
check(unlock.Active == true and string.find(unlock.Text, "1 POINT", 1, true), "Eligible node cannot be unlocked")
unlock.Activated.Fire()
check(GemClient.Profile.Augments.Unlocked.ServoFlurry and GemClient.Profile.Augments.Points == 2 and unlock.Active == false, "Unlock UI did not update saved state")
local reset = find("TextButton", function(o) return o.Text == "RESET & REFUND" end)
check(reset.Active, "Spent points cannot be refunded")
player.attributes.CombatSession = "PvP"
player.events.CombatSession.Fire()
check(reset.Active == false, "UI permits reset during Arena session")
player.attributes.CombatSession = nil
player.events.CombatSession.Fire()
reset.Activated.Fire()
check(not GemClient.Profile.Augments.Unlocked.ServoFlurry and GemClient.Profile.Augments.Points == 3, "UI reset failed to refund")
local panel = find("Frame", function(o) return o.Parent == gui and o.Size and o.Size.X.Scale == 1 end)
panel.AbsoluteSize = { X = 336, Y = 640 }
panel:GetPropertyChangedSignal("AbsoluteSize").Fire()
check(cards() == 6, "Portrait tree did not switch to one readable branch")
find("TextButton", function(o) return o.Text == "Gem Surges" end).Activated.Fire()
check(cards() == 6 and card("Cryo Lance") ~= nil, "Mobile branch tab failed")
card("Cryo Shield").Activated.Fire()
check(unlock.Active == false and unlock.Text == "PREREQUISITE LOCKED", "Surge prerequisites ignored by UI")
UI.close()
check(not UI.isOpen(), "Tree failed to close")
UI.toggle()
check(UI.isOpen(), "Tree toggle failed")
print("PASS: " .. count .. " real Augment Tree UI checks (desktop/portrait branches, locked nodes, unlocks, refunds and modal lifecycle)")
