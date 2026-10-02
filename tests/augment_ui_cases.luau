local count = 0
local function check(ok, message) count += 1; assert(ok, message) end
local function find(class, match)
	for _, object in objects do
		if not object.Destroyed and object.ClassName == class and match(object) then return object end
	end
	error("UI object missing: " .. class)
end
-- A node is a medallion button tagged with its id.
local function card(name)
	return find("TextButton", function(o)
		local id = o["@AugmentNode"]
		return id ~= nil and Tree.Nodes[id].Name == name
	end)
end
local function cards()
	local total = 0
	for _, o in objects do
		if not o.Destroyed and o.ClassName == "TextButton" and o["@AugmentNode"] then total += 1 end
	end
	return total
end
local function tab(name)
	return find("TextLabel", function(o) return o.Text == name and o.Parent.ClassName == "TextButton" end).Parent
end
local function label(text)
	return find("TextLabel", function(o) return o.Text == text end)
end
local function has(text)
	for _, o in objects do
		if not o.Destroyed and o.Text == text then return true end
	end
	return false
end
local gui = find("ScreenGui", function(o) return o.Name == "AugmentTree" end)
check(not UI.isOpen() and not gui.Enabled, "Tree opened on boot")
UI.open()
check(UI.isOpen() and cards() == 6, "Sheet did not show one branch of six medallions")
check(tab("Rig Maneuvers") and tab("Gem Surges") and tab("Passive Augments"), "Branch tabs missing")
check(has("1/18") and has("1") and has("TIER I") and has("🔒  REACH AUGMENT LEVEL 3"), "Ranks, level or tier gates missing")
local button = find("TextButton", function(o) return o.Text and string.find(o.Text, "UPGRADE TO RANK II", 1, true) end)
check(button.Active == true, "Starter node cannot be ranked up")
local reset = find("TextButton", function(o) return o.Text == "Nothing to refund yet" end)
check(reset.Active == false, "Nothing spent, yet refund is offered")
card("Armor Piercer").Activated.Fire()
check(button.Active == false and string.find(button.Text, "PREREQUISITE LOCKED", 1, true), "Locked node has invalid state")
card("Kinetic Ram").Activated.Fire()
check(button.Active == false and string.find(button.Text, "REACH LEVEL 3", 1, true), "Tier gate ignored by UI")
card("Servo Flurry").Activated.Fire()
check(button.Active == true and button.Text == "LEARN  ·  1 POINT", "Eligible node cannot be learned")
button.Activated.Fire()
check(GemClient.Profile.Augments.Unlocked.ServoFlurry and GemClient.Profile.Augments.Points == 2, "Learn did not update saved state")
check(string.find(button.Text, "UPGRADE TO RANK II  ·  1 POINT", 1, true) and has("RANK I / III"), "Learned node does not offer rank II")
button.Activated.Fire()
check(Tree.rank(GemClient.Profile, "ServoFlurry") == 2 and GemClient.Profile.Augments.Points == 1, "Upgrade did not raise the rank")
check(has("NEXT  ·  RANK III") and string.find(button.Text, "NEED 2 POINTS", 1, true) and button.Active == false, "Rank III cost or next-rank panel wrong")
check(has("3/18"), "Branch rank count did not update")
check(reset.Active and string.find(reset.Text, "2 points", 1, true), "Spent points cannot be refunded")
player.attributes.CombatSession = "PvP"
player.events.CombatSession.Fire()
check(reset.Active == false and button.Active == false, "UI permits changes during Arena session")
player.attributes.CombatSession = nil
player.events.CombatSession.Fire()
reset.Activated.Fire()
check(not GemClient.Profile.Augments.Unlocked.ServoFlurry and GemClient.Profile.Augments.Points == 3, "UI reset failed to refund")
tab("Gem Surges").Activated.Fire()
check(cards() == 6 and card("Cryo Lance") ~= nil, "Branch tab failed")
card("Cryo Shield").Activated.Fire()
check(button.Active == false and string.find(button.Text, "PREREQUISITE LOCKED", 1, true), "Surge prerequisites ignored by UI")
tab("Passive Augments").Activated.Fire()
check(cards() == 6 and card("Blade Calibration") ~= nil, "Passive branch tab failed")
card("Blade Calibration").Activated.Fire()
check(button.Active == true and has("Sword damage") and has("+5%  ▲"), "Passive node details missing")
UI.close()
check(not UI.isOpen(), "Tree failed to close")
UI.toggle()
check(UI.isOpen(), "Tree toggle failed")
print("PASS: " .. count .. " real Augment Tree UI checks (tier gates, ranks, learn/upgrade, refunds, combat lock, tabs and modal lifecycle)")
