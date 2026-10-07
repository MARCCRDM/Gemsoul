-- lune run tests/rig_pose_cases.luau <repo>
-- The real RivalPose.update on the three kinds of body a player's avatar can
-- be (R15 Motor6Ds, Roblox's upgraded joints with the old Motor6D switched
-- off, and R6), and the replay of a blow that arrives after it landed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3
local ROOT = process.args[1] or "."
local RivalPose = luau.load(fs.readFile(ROOT .. "/src/shared/RivalPose.luau"), {
	debugName = "RivalPose",
	environment = setmetatable({ CFrame = CFrame, Vector3 = Vector3, Instance = Instance }, { __index = _G }),
})()
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function part(model, name, size, at)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, CFrame.new(at)
	p.Parent = model
	return p
end
local function humanoid(model)
	local h = Instance.new("Humanoid")
	h.Parent = model
	h.MaxHealth, h.Health = 100, 100
end
local function motor(name, p0, p1, at, rotation)
	local m = Instance.new("Motor6D")
	m.Name, m.Part0, m.Part1 = name, p0, p1
	local joint = CFrame.new(at) * (rotation or CFrame.identity)
	m.C0 = p0.CFrame:Inverse() * joint
	m.C1 = p1.CFrame:Inverse() * joint
	return m
end
-- Where an arm points (down along it), from the joint's current C0.
local function armDown(m: Motor6D)
	local cf = m.Part0.CFrame * m.C0 * m.C1:Inverse()
	return -cf.UpVector
end
local function run(model, attrs, from, to)
	for k, v in attrs do
		model:SetAttribute(k, v)
	end
	local t = from
	RivalPose.update(model, 1 / 60, t, 0)
	while t < to do
		t += 1 / 60
		RivalPose.update(model, 1 / 60, t, 1)
	end
end

-- An R15 body: the guard raises the shield arm forward (its arm points ahead, -Z).
local function r15(upgraded: boolean)
	local m = Instance.new("Model")
	local torso = part(m, "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.8, 0))
	local arm = part(m, "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.85, 0))
	part(m, "Head", Vector3.new(1, 1, 1), Vector3.new(0, 2.2, 0))
	humanoid(m)
	local shoulder = motor("LeftShoulder", torso, arm, Vector3.new(-1.5, 1.35, 0))
	shoulder.Parent = arm
	local constraint
	if upgraded then
		-- Roblox's upgraded avatar joints: the old Motor6D left switched off.
		shoulder.Enabled = false
		local a0 = Instance.new("Attachment")
		a0.Name, a0.CFrame, a0.Parent = "LeftShoulderRigAttachment", shoulder.C0, torso
		local a1 = Instance.new("Attachment")
		a1.Name, a1.CFrame, a1.Parent = "LeftShoulderRigAttachment", shoulder.C1, arm
		constraint = Instance.new("AnimationConstraint")
		constraint.Name, constraint.Attachment0, constraint.Attachment1 = "LeftShoulder", a0, a1
		constraint.Parent = arm
	end
	m.Parent = Instance.new("Folder")
	return m, shoulder, constraint
end
do
	local model, shoulder = r15(false)
	run(model, { GuardUntil = 110 }, 100, 101)
	check(armDown(shoulder).Z < -0.5, "R15: guard didn't raise the shield arm forward")
end
do
	local model, shoulder, constraint = r15(true)
	local restMotor = shoulder.C0
	local restAttach = constraint.Attachment0.CFrame
	run(model, { GuardUntil = 110 }, 100, 101)
	check(shoulder.C0 == restMotor, "Upgraded joints: bent the switched-off Motor6D (moves nothing)")
	check(constraint.Attachment0.CFrame ~= restAttach, "Upgraded joints: the live joint wasn't bent")
	local info = RivalPose.inspect(model)
	check(info and info.Kind == "upgraded joints", "Upgraded joints not reported as such")
end

-- An R6 body: joints on the Torso, rotated frames.
do
	local m = Instance.new("Model")
	local root = part(m, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	local torso = part(m, "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	local arm = part(m, "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	part(m, "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0))
	humanoid(m)
	motor("RootJoint", root, torso, Vector3.new(0, 0, 0), CFrame.Angles(-math.pi / 2, 0, math.pi)).Parent = root
	local shoulder = motor("Left Shoulder", torso, arm, Vector3.new(-1, 0.5, 0), CFrame.Angles(0, -math.pi / 2, 0))
	shoulder.Parent = torso
	m.Parent = Instance.new("Folder")
	check(armDown(shoulder).Y < -0.9, "R6 rig built wrong")
	run(m, { GuardUntil = 110 }, 100, 101)
	check(armDown(shoulder).Z < -0.5, "R6: guard didn't raise the shield arm forward")
	check(RivalPose.inspect(m).Kind == "R6", "R6 body not reported as such")
end

-- A player's swing arrives after it landed (ActionStart = ActionAt, seen
-- 0.25 s late): it's replayed from when it's seen, wind-up first.
do
	local model = r15(false)
	local torso = model.UpperTorso
	local arm = part(model, "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.85, 0))
	motor("RightShoulder", torso, arm, Vector3.new(1.5, 1.35, 0)).Parent = arm
	local shoulder = arm.RightShoulder
	-- Seen late: 0.25 s after it landed.
	run(model, { ActionKind = "Slash", ActionStart = 100, ActionAt = 100, ActionSide = 1 }, 100.25, 100.4)
	local raised = armDown(shoulder)
	check(raised.Y > -0.6, "A late swing didn't show its wind-up")
	run(model, {}, 100.4, 100.62)
	local swung = armDown(shoulder)
	check(swung.X < raised.X - 0.3, "A late swing didn't cut across")
end
print("PASS: " .. checks .. " rig pose checks (R15, upgraded joints, R6, late swings)")
