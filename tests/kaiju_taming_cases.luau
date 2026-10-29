-- KaijuTaming on screen: a weakened wild kaiju glows gold and its plate reads
-- CATCH and its chance (no sign of its own over the fight) (not a healthy one, not a far one, not one being tamed);
-- a tame cast draws a beam and motes closing in; the tamer's bar fills and
-- ends on the server's result, then goes.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function boardFor(model)
	for _, child in playerGui:GetChildren() do
		if child.ClassName == "BillboardGui" and child.Adornee == model.PrimaryPart then
			return child
		end
	end
	return nil
end

Taming.start()
local healthy = wildKaiju("Wild Fire Bulwark", Vector3.new(20, 3, 0), 0.8)
local weak = wildKaiju("Wild Frost Razorback", Vector3.new(-20, 3, 0), 0.3)
local far = wildKaiju("Wild Ion Carapace", Vector3.new(400, 3, 0), 0.1)
frames(0.3)
-- Ready: the weak one near you glows, with its chance; the others don't.
check(healthy:FindFirstChildOfClass("Highlight") == nil and boardFor(healthy) == nil, "A healthy kaiju glows ready")
local glow = weak:FindFirstChildOfClass("Highlight")
check(glow ~= nil and glow.Adornee == weak, "A weakened kaiju near you doesn't glow")
local chance = Kaiju.tameChance(90, 300)
check(
	catchText[weak] == string.format("CATCH · %d%%", math.floor(chance * 100 + 0.5)),
	"The ready words are wrong: " .. tostring(catchText[weak])
)
check(boardFor(weak) == nil, "A sign of its own over a ready kaiju (it covers the fight)")
check(catchText[healthy] == nil and catchText[far] == nil, "A plate that can't be caught says CATCH")
check(far:FindFirstChildOfClass("Highlight") == nil, "A kaiju across the quarry glows")
check(Taming.ready(weak) and not Taming.ready(healthy), "ready() is wrong")
weak:SetAttribute("KaijuTries", Kaiju.TameTries)
check(not Taming.ready(weak), "Exhausted catch attempts must not show ready")
weak:SetAttribute("KaijuTries", 0)
-- It pulses.
local before = glow.FillTransparency
frames(0.2)
check(glow.FillTransparency ~= before, "The glow doesn't pulse")
-- Out of the Outpost: no glow.
localPlayer:SetAttribute("Outpost", false)
frames(0.3)
check(weak:FindFirstChildOfClass("Highlight") == nil, "It glows outside the Outpost")
localPlayer:SetAttribute("Outpost", true)
frames(0.3)
check(weak:FindFirstChildOfClass("Highlight") ~= nil, "The glow didn't come back")

-- The cast: the glow goes, a beam from your hand and motes closing in.
weak:SetAttribute("KaijuTameBy", 7)
weak:SetAttribute("KaijuTameEnds", serverClock + Kaiju.Tame.Cast)
Taming.cast(weak, chance, Kaiju.Tame.Cast)
frames(0.3)
check(not Taming.ready(weak) and weak:FindFirstChildOfClass("Highlight") == nil, "Still glowing ready while held")
check(catchText[weak] == nil, "Its plate still says CATCH while held")
local hold = workspace:FindFirstChild("TameHold")
check(hold ~= nil, "No tame beam drawn")
local beams, motes = 0, {}
for _, child in hold:GetChildren() do
	if child.ClassName == "Beam" then
		beams += 1
		check(child.Attachment0.Parent == myHand and child.Attachment1.Parent == weak.PrimaryPart, "The beam isn't hand to kaiju")
	elseif child.ClassName == "Part" then
		table.insert(motes, child)
	end
end
check(beams == 2 and #motes == 12, "Not two beams and twelve motes: " .. beams .. ", " .. #motes)
local function spread()
	local centre, total = weak.PrimaryPart.Position, 0
	for _, mote in motes do
		local d = mote.Position - centre
		total += math.sqrt(d.X * d.X + d.Z * d.Z)
	end
	return total / #motes
end
local early = spread()
-- The tamer's bar: CATCHING, the chance, filling.
local gui = playerGui:FindFirstChild("KaijuTaming")
check(gui and gui.Enabled, "No cast bar")
local function labels()
	local out = {}
	for _, o in objects do
		if o.ClassName == "TextLabel" and o.Text and o.Text ~= "" then
			out[o.Text] = true
		end
	end
	return out
end
check(labels()["CATCHING WILD FROST RAZORBACK"], "The bar doesn't say what you're taming")
check(Taming.casting(), "casting() false mid-cast")
local fillAt = nil
for _, o in objects do
	if o.ClassName == "Frame" and o.BackgroundColor3 and o.Size and o.Size.Y.Scale == 1 and o.Parent and o.Parent.ClipsDescendants then
		fillAt = o
	end
end
check(fillAt ~= nil, "No fill in the bar")
local filled = fillAt.Size.X.Scale
frames(1.6)
check(fillAt.Size.X.Scale > filled, "The bar didn't fill")
check(spread() < early, "The motes didn't close in")
check(table.find(sounds, "Shield"), "No sound when the cast starts")

-- The end: CAUGHT! from the server, then the bar goes; the beam goes with
-- the hold.
localPlayer:SetAttribute("TameResult", "Tamed")
localPlayer:SetAttribute("TameResultAt", serverClock)
check(labels()["CAUGHT!"] and not Taming.casting(), "The bar didn't say CAUGHT!")
check(table.find(sounds, "Combo"), "No sound for a tame")
weak:SetAttribute("KaijuTameBy", nil)
frames(0.3)
check(workspace:FindFirstChild("TameHold") == nil, "The beam stayed after the hold")
frames(2)
check(not gui.Enabled, "The bar stayed up after the result")
-- A broken cast says so.
Taming.cast(weak, chance, Kaiju.Tame.Cast)
localPlayer:SetAttribute("TameResult", "Interrupted")
localPlayer:SetAttribute("TameResultAt", serverClock + 1)
check(labels()["CATCH BROKEN"] and gui.Enabled, "A broken tame didn't show")
-- A model gone takes its marks with it.
weak.Parent = nil
frames(0.3)
check(catchText[weak] == nil, "A gone kaiju's ready words stayed")
-- On a phone, the same: its plate says so, no sign over it.
phoneMode = true
local phoneWeak = wildKaiju("Wild Ion Razorback", Vector3.new(-24, 3, 0), 0.3)
frames(0.3)
check(catchText[phoneWeak] ~= nil and boardFor(phoneWeak) == nil, "On a phone a ready kaiju's plate doesn't say CATCH")
phoneWeak.Parent = nil
frames(0.3)
check(catchText[phoneWeak] == nil, "A gone kaiju's plate kept CATCH on a phone")
phoneMode = false

print(string.format("PASS: %d kaiju taming checks (ready glow and chance, not healthy/far/held, the beam and motes, the cast bar, results)", checks))
