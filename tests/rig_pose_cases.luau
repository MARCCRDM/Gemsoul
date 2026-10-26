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
	check(raised.Y > -0.85, "A late swing didn't show its wind-up")
	run(model, {}, 100.4, 100.62)
	local swung = armDown(shoulder)
	check((swung - raised).Magnitude > 0.5, "A late swing didn't cut through")
end
-- A held blow (the server poses it "Charge" from BeginAttack): the arm
-- draws back first, then once the hold is a heavy it's raised overhead,
-- straining; held too long it sags. Its timings are the combat rules'.
do
	local source = fs.readFile(ROOT .. "/src/shared/CombatActions.luau")
	local c = RivalPose.Charge
	check(tonumber(source:match("Charge = ([%d%.]+),")) == c.Heavy, "Charge.Heavy isn't the heavy's charge")
	check(tonumber(source:match("Actions.PerfectAt = ([%d%.]+)")) == c.Full, "Charge.Full isn't PerfectAt")
	check(tonumber(source:match("Actions.OverchargeAt = ([%d%.]+)")) == c.Over, "Charge.Over isn't OverchargeAt")
	local hold = { ActionKind = "Charge", ActionStart = 0, ActionAt = 3, ActionSide = 1 }
	local early = RivalPose.pose(hold, 0.3, true).RightShoulder[1]
	local heavy = RivalPose.pose(hold, c.Full, true)
	check(early < 2.2, "A short hold already showed a heavy (" .. early .. ")")
	check(heavy.RightShoulder[1] > 2.25 and heavy.RightShoulder[1] > early + 0.5, "A heavy's hold isn't raised overhead (" .. heavy.RightShoulder[1] .. ")")
	check(heavy.RightKnee[1] < -0.4, "A heavy's hold isn't braced on bent legs")
	check(RivalPose.pose(hold, 1.5, true).RightShoulder[1] < heavy.RightShoulder[1] - 0.1, "An overcharged hold doesn't sag")
	check(next((RivalPose.pose(hold, 3.1, true))) == nil, "A hold past the server's cap still shows")
end
-- Seen held, then let go: the heavy comes down at once from the raised
-- hold; seen cold, it shows a wind-up first.
do
	local function body()
		local model = r15(false)
		local torso = model.UpperTorso
		local arm = part(model, "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.85, 0))
		motor("RightShoulder", torso, arm, Vector3.new(1.5, 1.35, 0)).Parent = arm
		return model, arm.RightShoulder
	end
	local held, heldArm = body()
	run(held, { ActionKind = "Charge", ActionStart = 100, ActionAt = 103, ActionSide = 1 }, 100, 100.8)
	local raised = armDown(heldArm)
	check(raised.Y > 0.3, "Held as a heavy, the arm isn't up (" .. raised.Y .. ")")
	run(held, { ActionKind = "Heavy", ActionStart = 100.85, ActionAt = 100.85 }, 100.8, 101.02)
	local chopped = armDown(heldArm)
	check(chopped.Y < raised.Y - 0.5, "A heavy from a seen hold didn't come straight down")
	local cold, coldArm = body()
	run(cold, { ActionKind = "Heavy", ActionStart = 100.85, ActionAt = 100.85, ActionSide = 1 }, 100.85, 101.02)
	check(armDown(coldArm).Y > chopped.Y + 0.3, "A heavy seen cold skipped its wind-up")
end
-- Eye to eye: given a foe's head (lookAt), the head turns to it, up or down,
-- left or right, within the neck's reach; without one it comes back.
do
	local model = r15(false)
	local torso, head = model.UpperTorso, model.Head
	local neck = motor("Neck", torso, head, Vector3.new(0, 1.6, 0))
	neck.Parent = head
	local function facing()
		return (neck.Part0.CFrame * neck.C0 * neck.C1:Inverse()).LookVector
	end
	local function watch(point, rest)
		local t = 200
		RivalPose.update(model, 1 / 60, t, 0, rest, nil, point)
		for _ = 1, 90 do
			t += 1 / 60
			RivalPose.update(model, 1 / 60, t, 1, rest, nil, point)
		end
	end
	-- Ahead, to the left and taller (a big rival's head).
	local up = Vector3.new(-6, 5, -10)
	watch(up)
	local look = facing()
	local want = (up - head.CFrame.Position).Unit
	check(look.X < -0.3 and look.Y > 0.2, "The head didn't turn up and left to the foe's head")
	check(look:Dot(want) > 0.97, "The head isn't on the foe's head: " .. tostring(look))
	-- Ahead and to the right, lower down (a short foe, a crouch).
	local down = Vector3.new(5, 0.5, -8)
	watch(down, true)
	look = facing()
	check(look.X > 0.3 and look.Y < -0.05, "The head didn't turn right and down (at rest too)")
	-- Right behind: the neck turns as far as it goes, no further.
	watch(Vector3.new(0.5, 2.2, 12))
	local yaw = math.atan2(-facing().X, -facing().Z)
	check(math.abs(yaw) <= RivalPose.LookYaw + 0.45, "The head spun past the neck's reach")
	-- Nobody to look at: back to facing ahead.
	watch(nil)
	check(facing():Dot(Vector3.new(0, 0, -1)) > 0.97, "The head didn't come back without a foe")
	check(RivalPose.lookAngles(model, head.CFrame.Position + Vector3.new(0, 5, 0)) == nil, "Straight up has no heading")
end
-- Out of a fight: reset puts every joint straight back to rest (a body sent
-- back to the lobby mid-pose stood crouched), clears its animation
-- transforms, and the next calm frame keeps it there.
do
	local model, shoulder = r15(false)
	local rest = shoulder.C0
	run(model, { GuardUntil = 110 }, 100, 101)
	check(shoulder.C0 ~= rest, "The guard didn't bend the shoulder (nothing to reset)")
	shoulder.Transform = CFrame.Angles(0.8, 0, 0)
	RivalPose.reset(model)
	check(shoulder.C0 == rest, "Reset didn't put the shoulder back to rest")
	check(shoulder.Transform == CFrame.identity, "Reset left an animation transform on the joint")
	model:SetAttribute("GuardUntil", nil)
	RivalPose.update(model, 1 / 60, 102, 2, true)
	check(shoulder.C0 == rest, "The first calm frame after a reset bent the joint again")
	check(type(RivalPose.Attributes) == "table" and table.find(RivalPose.Attributes, "ActionKind"), "The pose attributes aren't listed")
end
-- A creature standing idle breathes: its waist is written again and again
-- as it rises and falls (slow motion was once never written: it stood
-- frozen), but not every frame, and it follows the breath smoothly.
do
	local m = Instance.new("Model")
	local lower = part(m, "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 0, 0))
	local upper = part(m, "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 1, 0))
	part(m, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0.5, 0))
	humanoid(m)
	local waist = motor("Waist", lower, upper, Vector3.new(0, 0.2, 0))
	waist.Parent = upper
	m:SetAttribute("CreatureShape", "Chimpanzini")
	m.Parent = Instance.new("Folder")
	-- (Lune's Model has no GetScale: the body as RivalPose sees it.)
	local model = m
	m = setmetatable({
		GetScale = function()
			return 1
		end,
	}, {
		__index = function(_, key)
			local value = model[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(model, ...)
				end
			end
			return value
		end,
	})
	local writes, last, jump, frames = 0, waist.C0, 0, 0
	local t = 200
	RivalPose.update(m, 1 / 60, t, t)
	for _ = 1, 90 do -- (into its stance first)
		t += 1 / 60
		RivalPose.update(m, 1 / 60, t, t)
	end
	last = waist.C0
	for _ = 1, 240 do
		t += 1 / 60
		frames += 1
		RivalPose.update(m, 1 / 60, t, t)
		if waist.C0 ~= last then
			writes += 1
			local a = select(1, last:ToEulerAnglesXYZ())
			local b = select(1, waist.C0:ToEulerAnglesXYZ())
			jump = math.max(jump, math.abs(a - b))
			last = waist.C0
		end
	end
	check(writes >= 8, "An idle creature's breath was hardly ever written: " .. writes)
	check(writes < frames, "An idle creature was rewritten every frame")
	check(jump < 0.01, "An idle creature's breath jumped: " .. jump)
end
print("PASS: " .. checks .. " rig pose checks (R15, upgraded joints, R6, late swings, eye to eye, reset)")
