-- lune run tests/basics_demo_cases.luau <repo>
-- The combat basics' live demo (Client BasicsDemo): two R15 fighters built
-- as Server.Duelist builds them (here with a plain sword and shield), the
-- demo stepped through each line on a clock of its own. The fighters really
-- move (the game's own poses, Shared.RivalPose, laid out from their joints),
-- the rival flinches when hit, the hero's guard goes up when it should, and
-- the overlay says what's happening: the topic, the control, what landed,
-- and for abilities the gems and the charge bar.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local R = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3, Enum = R.Instance, R.Vector3, R.CFrame, R.Color3, R.Enum

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end

local BODY = {
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.2, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.8, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.2, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.85, 0) },
	{ "RightLowerArm", Vector3.new(1, 1, 1), Vector3.new(1.5, -0.15, 0) },
	{ "RightHand", Vector3.new(1, 0.3, 1), Vector3.new(1.5, -0.75, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.85, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, -0.15, 0) },
	{ "LeftHand", Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -0.75, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -0.9, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(0.5, -2.05, 0) },
	{ "RightFoot", Vector3.new(1, 0.3, 1), Vector3.new(0.5, -2.75, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -0.9, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(-0.5, -2.05, 0) },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -2.75, 0) },
}
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 0, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 0, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 1.6, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.5, 1.35, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.5, 0.35, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.5, -0.6, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.5, 1.35, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.5, 0.35, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.5, -0.6, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, -0.3, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, -1.5, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, -2.6, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, -0.3, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, -1.5, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, -2.6, 0) },
}
local function rig(name, skin, armor)
	local m = Instance.new("Model")
	m.Name = name
	local parts = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = m
	parts.HumanoidRootPart = root
	for _, spec in BODY do
		local p = Instance.new("Part")
		p.Name = spec[1]
		p.Size = spec[2]
		p.CFrame = CFrame.new(spec[3])
		p.Color = if spec[1]:find("Torso") or spec[1]:find("Upper") then armor else skin
		p.Parent = m
		parts[spec[1]] = p
	end
	for _, spec in JOINTS do
		local p0, p1 = parts[spec[2]], parts[spec[3]]
		local at = CFrame.new(spec[4])
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0, motor.Part1 = p0, p1
		motor.C0 = p0.CFrame:Inverse() * at
		motor.C1 = p1.CFrame:Inverse() * at
		motor.Parent = p1
	end
	-- a sword in the right hand (pointing forward, -Z), a shield on the left forearm
	local hand = parts.RightHand
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.3, 0.2, 4)
	blade.Color = Color3.fromRGB(210, 216, 228)
	blade.Material = Enum.Material.Metal
	blade.CFrame = hand.CFrame * CFrame.new(0, -0.1, -2)
	blade.Parent = m
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = hand, blade
	w.C0 = CFrame.new(0, -0.1, -2)
	w.Parent = blade
	local arm = parts.LeftLowerArm
	local shield = Instance.new("Part")
	shield.Name = "Shield"
	shield.Size = Vector3.new(0.3, 2.4, 2)
	shield.Color = armor
	shield.CFrame = arm.CFrame * CFrame.new(-0.7, 0, 0)
	shield.Parent = m
	local w2 = Instance.new("Weld")
	w2.Part0, w2.Part1 = arm, shield
	w2.C0 = CFrame.new(-0.7, 0, 0)
	w2.Parent = shield
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 1.9
	hum.MaxHealth = 100
	hum.Health = 100
	hum.Parent = m
	return m
end

-- The module under test, with stand-ins for what it needs from the game.
local clock = 0
local tweens = {
	Create = function(_, inst, _, goal)
		return { Play = function()
			for k, v in goal do
				inst[k] = v
			end
		end }
	end,
}
local modules = {
	GemClient = { request = function() return { Ok = true } end },
	UiKit = { round = function(p, r)
		local c = Instance.new("UICorner")
		c.Parent = p
	end },
}
local shared = {
	RivalPose = luau.load(fs.readFile(ROOT .. "/src/shared/RivalPose.luau"), { debugName = "RivalPose", environment = setmetatable({
		CFrame = CFrame, Vector3 = Vector3, Enum = Enum, Color3 = Color3, Instance = Instance,
		typeof = R.typeof or typeof,
	}, { __index = _G }) })(),
}
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "TweenService" then return tweens end
		if n == "ReplicatedStorage" then return { Shared = setmetatable({}, { __index = function(_, k) return k end }) } end
		return {}
	end },
	script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
	require = function(x)
		return modules[x] or shared[x] or error("no stub " .. tostring(x))
	end,
	os = { clock = function() return clock end },
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3,
	UDim2 = R.UDim2, UDim = R.UDim, Vector2 = R.Vector2, Enum = R.Enum,
	ColorSequence = R.ColorSequence, TweenInfo = { new = function() return {} end },
	typeof = R.typeof or typeof,
}, { __index = _G })
local Demo = luau.load(fs.readFile(ROOT .. "/src/client/Modules/BasicsDemo.luau"), { debugName = "BasicsDemo", environment = env })()

Demo._key = function(part)
	return part:GetFullName()
end
Demo._key = function(part)
	return part:GetFullName()
end
local holder = Instance.new("Folder")
local stage = Instance.new("Frame")
stage.Parent = holder
local hero = rig("Hero", Color3.fromRGB(214, 170, 130), Color3.fromRGB(70, 110, 170))
local foe = rig("Foe", Color3.fromRGB(190, 140, 110), Color3.fromRGB(160, 60, 60))
local demo = Demo.new(stage, hero, foe, false)
local view = stage:FindFirstChild("Demo")
check(view and view:IsA("ViewportFrame") and view:FindFirstChildOfClass("Camera"), "No viewport with a camera on the stage")
local world = view:FindFirstChildOfClass("WorldModel")
local heroCopy, foeCopy = world:FindFirstChild("Hero"), world:FindFirstChild("Foe")
check(heroCopy and foeCopy, "The fighters aren't on the stage")
for _, p in heroCopy:GetDescendants() do
	if p:IsA("BasePart") then
		check(p.Anchored and not p.CanCollide, "A fighter's part isn't anchored: " .. p.Name)
	end
end
-- on the floor, facing each other
local function root(m)
	return m.HumanoidRootPart.CFrame
end
check(math.abs(root(heroCopy).Position.Y - 2.9) < 0.05 and math.abs(root(foeCopy).Position.Y - 2.9) < 0.05, "The fighters aren't standing on the floor")
check(root(heroCopy).LookVector.X > 0.99 and root(foeCopy).LookVector.X < -0.99, "The fighters don't face each other")
check(math.abs(heroCopy.LeftFoot.CFrame.Position.Y - 0.15) < 0.2, "The hero's feet aren't on the floor")
local overlay = stage:FindFirstChild("Overlay")
local function find(name)
	for _, d in overlay:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end
local function texts()
	local list = {}
	for _, d in overlay:GetDescendants() do
		if d:IsA("TextLabel") and d.Text ~= "" then
			list[d.Text] = true
		end
	end
	return list
end
local rest = heroCopy.Blade.CFrame
local lengths = { BasicsAttack = 10.85, BasicsBlock = 8.94, BasicsAbilities = 11.07 }
for index, name in { "BasicsAttack", "BasicsBlock", "BasicsAbilities" } do
	demo.show(name, index, 3)
	local spec = Demo.Scripts[name]
	local base = clock
	local t = 0
	local seen, swung, flinched, guarded, keyShown = {}, 0, false, false, {}
	local foeChest = foeCopy.UpperTorso.CFrame
	local barBefore, barAfter = nil, nil
	while t < lengths[name] do
		t += 1 / 60
		clock = base + t
		demo.step(name, t)
		for text in texts() do
			seen[text] = true
		end
		if (heroCopy.Blade.CFrame.Position - rest.Position).Magnitude > 1 then
			swung += 1
		end
		if (foeCopy.UpperTorso.CFrame.Position - foeChest.Position).Magnitude > 0.05 or (foeCopy.UpperTorso.CFrame.LookVector - foeChest.LookVector).Magnitude > 0.05 then
			flinched = true
		end
		-- the guard: the shield arm up across the body while it's held
		for _, g in spec.Guard or {} do
			if t > g[1] + 0.3 and t < g[2] then
				if heroCopy.Shield.CFrame.Position.Y > root(heroCopy).Position.Y + 0.6 then
					guarded = true
				end
			end
		end
		local key = find("Key")
		if key and key.Visible then
			keyShown[key:FindFirstChildOfClass("TextLabel").Text] = true
		end
		if spec.Spend then
			local fill = nil
			for _, d in overlay:GetDescendants() do
				if d:IsA("Frame") and d.Parent and d.Parent:IsA("Frame") and d.Parent.Size.Y.Scale < 0.05 and d.Parent.Size.Y.Scale > 0 then
					fill = d
				end
			end
			if fill and t > spec.Spend[1][1] - 0.2 and t < spec.Spend[1][1] - 0.05 then
				barBefore = fill.Size.X.Scale
			elseif fill and t > spec.Spend[1][1] + 0.1 and t < spec.Spend[1][1] + 0.2 then
				barAfter = fill.Size.X.Scale
			end
		end
	end
	check(seen[spec.Title], name .. ": its topic isn't shown")
	check(seen[string.format("%02d/03", index)], name .. ": its number isn't shown")
	for _, p in spec.Pops or {} do
		check(seen[p[2]], name .. ": never showed " .. p[2])
	end
	check(flinched, name .. ": the rival never moved")
	if name == "BasicsAttack" then
		check(swung > 30, name .. ": the hero's blade barely moved (" .. swung .. " frames)")
		check(keyShown.CLICK, name .. ": the attack's control never showed")
	elseif name == "BasicsBlock" then
		check(guarded, name .. ": the hero's guard never went up")
		check(keyShown["R-CLICK"], name .. ": the block's control never showed")
	else
		check(keyShown.Q and keyShown.E, name .. ": Q and E never showed")
		check(barBefore and barAfter and barAfter < barBefore - 0.2, name .. ": casting didn't spend charge (" .. tostring(barBefore) .. " -> " .. tostring(barAfter) .. ")")
	end
end
-- The narrator's welcome first: its own script (the fighters squared up,
-- the hero's arms thrown wide), the topic shown with no number.
do
	local opener = Demo.Scripts.TrainingBegins
	check(opener and opener.Title == "WELCOME, MINER" and #opener.Hero > 0, "No welcome script for the narrator's first line")
	local welcomeStage = Instance.new("Frame")
	local welcome = Demo.new(welcomeStage, hero, foe, false)
	welcome.show("TrainingBegins", 0, 3)
	local titles = {}
	for _, d in welcomeStage:FindFirstChild("Overlay"):GetDescendants() do
		if d:IsA("TextLabel") and d.Text ~= "" then
			titles[d.Text] = true
		end
	end
	check(titles["WELCOME, MINER"] and not titles["00/03"], "The welcome isn't shown as its topic, with no number")
	local copy = welcomeStage:FindFirstChild("Demo"):FindFirstChildOfClass("WorldModel"):FindFirstChild("Hero")
	local armRest = copy.RightUpperArm.CFrame
	local base = clock
	local raised = false
	local t = 0
	while t < 2 do
		t += 1 / 30
		clock = base + t
		welcome.step("TrainingBegins", t)
		if (copy.RightUpperArm.CFrame.LookVector - armRest.LookVector).Magnitude > 0.3 then
			raised = true
		end
	end
	welcome.destroy()
	check(raised, "The hero's greeting (arms wide) never showed")
end
-- on a phone: the controls by their buttons' names
do
	local phone = Demo.new(Instance.new("Frame"), hero, foe, true)
	phone.show("BasicsAttack", 1, 3)
	phone.step("BasicsAttack", 2.8)
	phone.destroy()
end
demo.destroy()
check(stage:FindFirstChild("Demo") == nil and stage:FindFirstChild("Overlay") == nil, "The demo left itself on the stage")
-- Wired in: the basics' screen asks for the fighters and plays the demo, the
-- LED panel only without them; the server builds them.
do
	local screen = fs.readFile(ROOT .. "/src/client/Modules/BasicsScreen.luau")
	check(screen:find("BasicsDemo.fighters(", 1, true) and screen:find("pcall(BasicsDemo.new, screen.Panel", 1, true) and screen:find("pcall(demo.step, name, t)", 1, true), "The basics' screen doesn't play the demo")
	check(screen:find("if not demo and scene and frame ~= last then", 1, true), "The LED panel isn't the fallback")
	-- (the welcome first, with the demo; what was watched sent to the server)
	check(screen:find('BasicsScreen.Opener = "TrainingBegins"', 1, true) and screen:find("table.insert(lines, 1, BasicsScreen.Opener)", 1, true), "The narrator's welcome doesn't open the lesson")
	check(screen:find('"BasicsSeen"', 1, true) and screen:find('seen("Done", false, watched)', 1, true), "What was watched isn't sent for the numbers")
	local server = fs.readFile(ROOT .. "/src/server/Systems/Duelist.luau")
	check(server:find('Shop.register("BasicsSeen"', 1, true) and server:find('"BasicsLesson"', 1, true), "The server doesn't count what was watched")
	local duelist = fs.readFile(ROOT .. "/src/server/Systems/Duelist.luau")
	check(duelist:find('Shop.register("BasicsDemo"', 1, true), "The server doesn't build the demo's fighters")
end
print(string.format("PASS: %d basics demo checks (two fighters on a stage, posed by the game's own fight poses: the attack's swings, combo and heavy, the guard and the blocks, the casts; the topic, the control, what landed, the gems and the charge)", checks))
process.exit(0)
