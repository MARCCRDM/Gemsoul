-- Pointing the way to the rocks (Client MineCue, Shared Outpost.MineCue):
-- the nearest rocks around you glow (nearest first, never a popped one,
-- measured flat in a mech), the one in reach amber with its label over it
-- saying how for the way you play, a healing crystal green; rocks you walk
-- away from stop glowing; the label goes with nothing in reach or when it
-- isn't wanted. Then that the Outpost drives it on foot and in a mech (the
-- label always in a mech, on foot while learning), and that a pad's X
-- swings from a mech.
-- Run by tests/run_mine_cue.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."
local Instance, Vector3, CFrame, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Enum
-- (a button's Activated, as the engine fires it)
local clicks = {}
roblox.implementProperty("GuiButton", "Activated", function(button)
	local key = button:GetFullName()
	clicks[key] = clicks[key] or {}
	local handlers = clicks[key]
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
		end,
	}
end)
local function click(button)
	for _, fn in clicks[button:GetFullName()] or {} do
		fn()
	end
end

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local Outpost = luau.load(fs.readFile(ROOT .. "/src/shared/Outpost.luau"), {
	debugName = "Outpost",
	environment = setmetatable({
		Color3 = roblox.Color3,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = Enum,
		Instance = Instance,
	}, { __index = _G }),
})()

-- The rules: past your reach (so the next rock shows before you get there),
-- a mech's further, a handful (Roblox draws at most 31 outlines at once), and
-- looked for often enough to follow you.
local spec = Outpost.MineCue
check(spec ~= nil, "No MineCue rules")
check(spec.Glow > Outpost.Reach * 2, "The glow reaches no further than the pick")
check(spec.MechGlow > spec.Glow and spec.MechGlow > Outpost.MechReach * 2, "A mech's glow reaches no further")
check(spec.Max >= 3 and spec.Max <= 8, "Too few rocks glow, or too many outlines: " .. spec.Max)
check(spec.Every > 0 and spec.Every <= 0.2, "The cue lags behind you")

-- MineCue, with the engine's bits it uses.
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
local player = { WaitForChild = function() return playerGui end }
local tweens = {}
local services = {
	Players = { LocalPlayer = player },
	TweenService = {
		Create = function(_, target, _, goal)
			local t = { Target = target, Goal = goal, Playing = false }
			function t:Play() self.Playing = true end
			function t:Cancel() self.Playing = false end
			table.insert(tweens, t)
			return t
		end,
	},
}
local IronUi = {
	Bold = Enum.Font.GothamBold,
	new = function(class, props, parent)
		local object = Instance.new(class)
		for k, v in props or {} do
			object[k] = v
		end
		object.Parent = parent
		return object
	end,
}
local UiKit = { round = function() end }
local modules = { IronUi = IronUi, UiKit = UiKit }
local MineCue = luau.load(fs.readFile(ROOT .. "/src/client/Modules/MineCue.luau"), {
	debugName = "MineCue",
	environment = setmetatable({
		game = { GetService = function(_, name) return services[name] end },
		script = { Parent = { IronUi = "IronUi", UiKit = "UiKit" } },
		require = function(name) return modules[name] end,
		Instance = Instance,
		Color3 = roblox.Color3,
		Vector3 = Vector3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = Enum,
		TweenInfo = { new = function(...) return { ... } end },
	}, { __index = _G }),
})()

-- A rock: a model with its body at `at`.
local workspace = Instance.new("Folder")
local nextId = 0
local function rock(at: Vector3, heal: boolean?)
	nextId += 1
	local model = Instance.new("Model")
	model.Name = "Rock" .. nextId
	local body = Instance.new("Part")
	body.Size = Vector3.new(6, 5, 6)
	body.CFrame = CFrame.new(at)
	body.Position = at -- (Lune keeps the two apart)
	body.Parent = model
	model.PrimaryPart = body
	model:SetAttribute("NodeId", nextId)
	if heal then
		model:SetAttribute("HealRock", true)
	end
	model.Parent = workspace
	return model
end
local function glowOf(model)
	return model:FindFirstChild("MineCue")
end

-- Near: nearest first, within range, at most max, never popped.
local me = Vector3.new(0, 3, 0)
local a = rock(Vector3.new(5, 3, 0))
local b = rock(Vector3.new(0, 3, 12))
local c = rock(Vector3.new(-30, 3, 0))
local far = rock(Vector3.new(100, 3, 0))
local popped = rock(Vector3.new(2, 3, 2))
popped:SetAttribute("Popped", 1)
local high = rock(Vector3.new(0, 60, 8)) -- (below a mech's cockpit: far straight up, near across the ground)
local all = { far, c, b, a, popped, high }
local near = MineCue.near(all, me, false, 42, 6)
check(#near == 3 and near[1] == a and near[2] == b and near[3] == c, "Near isn't the rocks in range, nearest first")
check(table.find(near, popped) == nil, "A popped rock glows")
check(table.find(near, far) == nil, "A rock across the quarry glows")
check(table.find(near, high) == nil, "A rock far straight up counted on foot")
local flat = MineCue.near(all, me, true, 42, 6)
check(table.find(flat, high) ~= nil and flat[1] == a and flat[2] == high, "A mech doesn't measure across the ground")
check(#MineCue.near(all, me, false, 42, 2) == 2, "More than max glow")
local loose = Instance.new("Model") -- (no body yet: streaming in)
check(#MineCue.near({ loose }, me, false, 42, 6) == 0, "A rock with no body counted")

-- The words, for the way you play.
check(MineCue.words(Enum.UserInputType.MouseButton1, false) == "Click to mine", "A mouse isn't told to click")
check(MineCue.words(Enum.UserInputType.Keyboard, false) == "Click to mine", "A keyboard isn't told to click")
check(MineCue.words(Enum.UserInputType.Touch, false) == "Tap to mine", "A phone isn't told to tap")
check(MineCue.words(Enum.UserInputType.Gamepad1, false) == "X to mine", "A pad isn't told its button")
check(MineCue.words(Enum.UserInputType.Touch, true) == "Tap to heal", "A healing crystal says mine")
check(MineCue.words(nil, false) == "Click to mine", "No input yet says nothing")

-- Shown: the near ones soft and unfilled, the target amber and filled, pulsing.
local swung = nil
MineCue.onSwing(function(id)
	swung = id
end)
MineCue.show(a, { a, b, c }, { Label = true, Mech = false, Input = Enum.UserInputType.Touch })
for _, model in { a, b, c } do
	check(glowOf(model) ~= nil and glowOf(model):IsA("Highlight"), model.Name .. " doesn't glow")
	check(glowOf(model).Adornee == model, model.Name .. "'s glow is on something else")
	check(glowOf(model).DepthMode == Enum.HighlightDepthMode.Occluded, "The glow shows through the quarry walls")
end
check(glowOf(a).OutlineColor == MineCue.Target and glowOf(a).FillTransparency < 1, "The rock in reach isn't the amber one")
check(glowOf(a).OutlineTransparency == 0, "The rock in reach isn't the brightest")
check(glowOf(b).OutlineColor == MineCue.Glow and glowOf(b).FillTransparency == 1, "A rock to walk to is filled in")
check(glowOf(b).OutlineTransparency > 0, "A rock to walk to glows as bright as the one in reach")
check(glowOf(far) == nil, "A rock not near glows")
local pulse = tweens[#tweens]
check(pulse and pulse.Target == glowOf(a) and pulse.Playing, "The rock in reach doesn't pulse")
-- The label: over the target, how to swing, a tap on it swings.
local label = playerGui:FindFirstChild("MineCue")
check(label and label:IsA("BillboardGui") and label.Enabled, "No label over the rock in reach")
check(label.Adornee == a.PrimaryPart and label.AlwaysOnTop, "The label isn't over the rock, or hides behind things")
check(label.StudsOffsetWorldSpace.Y > a.PrimaryPart.Size.Y / 2, "The label sits inside the rock")
local button = label:FindFirstChild("Swing")
check(button and button.Text == "Tap to mine", "The label doesn't say how")
check(label.Active and button.Active, "The label can't be tapped")
check(label.ResetOnSpawn == false, "The label goes on a respawn")
local smallSize = label.Size

-- Next tick: walked on, a new target; the old one glows soft; the far one went.
local d = rock(Vector3.new(-8, 3, 6))
MineCue.show(b, { b, d }, { Label = true, Mech = false, Input = Enum.UserInputType.MouseButton1 })
check(glowOf(a) == nil and glowOf(c) == nil, "A rock you walked away from still glows")
check(glowOf(b).OutlineColor == MineCue.Target and glowOf(b).FillTransparency < 1, "The new rock in reach isn't amber")
check(glowOf(d).OutlineColor == MineCue.Glow and glowOf(d).FillTransparency == 1, "The new rock to walk to isn't soft")
check(not pulse.Playing, "The old target's pulse runs on")
check(tweens[#tweens].Target == glowOf(b) and tweens[#tweens].Playing, "The new target doesn't pulse")
check(label.Adornee == b.PrimaryPart and button.Text == "Click to mine", "The label didn't follow the target")
-- Nothing in reach: the rocks still glow (to walk to), no label.
MineCue.show(nil, { b, d }, { Label = true })
check(not label.Enabled, "A label with nothing in reach")
check(glowOf(b).OutlineColor == MineCue.Glow and glowOf(b).FillTransparency == 1, "Out of reach, still amber")
-- Not wanted (on foot, past your first stones): the glow, no label.
MineCue.show(b, { b, d }, { Label = false })
check(not label.Enabled and glowOf(b).OutlineColor == MineCue.Target, "Without the label, the target doesn't glow")
-- In a mech: the label a size up (its camera sits further back).
MineCue.show(b, { b }, { Label = true, Mech = true, Input = Enum.UserInputType.MouseButton1 })
check(label.Enabled and label.Size.X.Offset > smallSize.X.Offset and button.TextSize > 15, "A mech's label isn't a size up")
-- A healing crystal: green, "to heal".
local h = rock(Vector3.new(3, 3, 3), true)
MineCue.show(h, { h, b }, { Label = true, Input = Enum.UserInputType.Touch })
check(glowOf(h).OutlineColor == MineCue.Heal and button.Text == "Tap to heal", "A healing crystal isn't green, or says mine")
-- A tap on the label swings at the rock it's over.
check(swung == nil, "Swung before a tap")
click(button)
check(swung == h:GetAttribute("NodeId"), "A tap on the label doesn't swing at its rock")
-- Hidden: nothing glows, no label.
MineCue.hide()
for _, model in { a, b, c, d, h } do
	check(glowOf(model) == nil, model.Name .. " glows after hide")
end
check(not label.Enabled, "The label stays after hide")

-- The Outpost drives it ---------------------------------------------------------------------------

local scene = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
check(scene:find("local MineCue = require(script.Parent.MineCue)", 1, true) ~= nil, "The Outpost has no rock cue")
check(scene:find("cueAt = now + Rules.MineCue.Every", 1, true) ~= nil, "The cue isn't paced by its rule")
-- On foot and in a mech: a mech glows further, across the ground, and
-- always labels; on foot, the label while learning.
check(scene:find("if mech then spec.MechGlow else spec.Glow", 1, true) ~= nil, "A mech doesn't glow further")
check(scene:find("root.Position,\n\t\tmech ~= nil,", 1, true) ~= nil, "A mech doesn't measure across the ground")
check(scene:find("Label = mech ~= nil or learning,", 1, true) ~= nil, "A mech doesn't always show the label")
check(scene:find("< Rules.MineButton.Training", 1, true) ~= nil, "On foot, the label isn't for learners")
check(scene:find("MineCue.show(nearestRock(), near, {", 1, true) ~= nil, "The target isn't the rock a swing would hit")
-- Never over a screen or a fight, nor in a mech that can't mine.
check(
	scene:find("if not active or cueBlocked or mech == false or not root or Spar.fighting(player) then\n\t\tMineCue.hide()", 1, true) ~= nil,
	"The cue shows over a screen or a fight"
)
check(scene:find("cueBlocked = blocked or not hud.Enabled", 1, true) ~= nil, "Opening a screen doesn't block the cue")
-- The label's tap swings, as a tap on the rock does.
check(scene:find("MineCue.onSwing(function(nodeId)\n\tOutpostScene.swing(nodeId)", 1, true) ~= nil, "The label's tap doesn't swing")
-- The old prompt-only label is gone (it never showed from a mech's cockpit).
check(scene:find("ClickToMine", 1, true) == nil and scene:find("miningPrompts", 1, true) == nil, "The old prompt label is still there")
-- A pad's X swings from a mech (on foot the rock's prompt takes it).
check(scene:find("input.KeyCode == Enum.KeyCode.ButtonX and MechPilot.of(player) ~= nil", 1, true) ~= nil, "A pad can't mine from a mech")

print(string.format("PASS: %d mine cue checks (the rocks near you glow, the one in reach amber with how to swing, on foot and in a mech)", checks))
