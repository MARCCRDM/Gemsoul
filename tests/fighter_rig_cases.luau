-- lune run tests/fighter_rig_cases.luau <repo>
-- Every player's body (FighterRig) is the rival's rig (Duelist), and the real
-- RivalPose finds and bends all of its joints the way it does the rival's.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3, Color3, Enum = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Enum
local ROOT = process.args[1] or "."
local env = setmetatable({ Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Color3 = Color3, Enum = Enum,
	game = { GetService = function(_, name) return { Name = name } end } }, { __index = _G })
local FighterRig = luau.load(fs.readFile(ROOT .. "/src/server/Systems/FighterRig.luau"), { debugName = "FighterRig", environment = env })()
local RivalPose = luau.load(fs.readFile(ROOT .. "/src/shared/RivalPose.luau"), { debugName = "RivalPose", environment = env })()
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
-- The rival's layout, from Duelist's own source.
local duel = fs.readFile(ROOT .. "/src/server/Systems/Duelist.luau")
local chunk = duel:sub(duel:find("local BODY = {", 1, true), duel:find("local function buildBody", 1, true) - 1)
local rival = luau.load(chunk .. "\nreturn BODY, JOINTS", { environment = env })
local BODY, JOINTS = rival()
check(#BODY == #FighterRig.BODY and #JOINTS == #FighterRig.JOINTS, "A player's body isn't the rival's layout")
for i, spec in BODY do
	local mine = FighterRig.BODY[i]
	check(mine[1] == spec[1] and mine[2] == spec[2] and mine[3] == spec[3], "Body part differs from the rival's: " .. spec[1])
end
for i, spec in JOINTS do
	local mine = FighterRig.JOINTS[i]
	check(mine[1] == spec[1] and mine[2] == spec[2] and mine[3] == spec[3] and mine[4] == spec[4], "Joint differs from the rival's: " .. spec[1])
end
-- Built and posed: every joint found as a Motor6D, and the guard raises the shield arm forward.
local rig = FighterRig.build()
rig.Parent = Instance.new("Folder")
local humanoid = rig:FindFirstChildOfClass("Humanoid")
humanoid.MaxHealth, humanoid.Health = 100, 100
check(humanoid.RigType == Enum.HumanoidRigType.R15, "Not an R15 body")
rig:SetAttribute("GuardUntil", 110)
local t = 100
RivalPose.update(rig, 1 / 60, t, 0)
while t < 101 do
	t += 1 / 60
	RivalPose.update(rig, 1 / 60, t, 1)
end
local info = RivalPose.inspect(rig)
check(info.Found == 10 and info.Kind == "Motor6D", "Not every joint found as a Motor6D")
local shoulder = rig.LeftUpperArm.LeftShoulder
local arm = shoulder.Part0.CFrame * shoulder.C0 * shoulder.C1:Inverse()
check((-arm.UpVector).Z < -0.5, "The guard didn't raise the shield arm forward")
-- Where a part is with the joints as posed (forward from the lower torso).
local function placed(name)
	local chain = { UpperTorso = { "LowerTorso", "Waist" }, LeftUpperArm = { "UpperTorso", "LeftShoulder" },
		LeftLowerArm = { "LeftUpperArm", "LeftElbow" } }
	if name == "LowerTorso" then
		return rig.LowerTorso.CFrame
	end
	local link = chain[name]
	local m = rig[name][link[2]]
	return placed(link[1]) * m.C0 * m.C1:Inverse()
end
-- The shield (on the outside of the left forearm) faces straight ahead, the
-- body square to the front.
local face = -placed("LeftLowerArm").RightVector
check(face.Z < -0.9 and math.abs(face.X) < 0.25, "The guard's shield doesn't face forward")
local look = placed("UpperTorso").LookVector
check(look.Z < -0.95, "The guard turns the body away from the front")
-- Walking with the guard up: the legs step, the shield stays square.
local hip = rig.RightUpperLeg.RightHip
local lowest, highest = math.huge, -math.huge
rig.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, -8)
for _ = 1, 90 do
	t += 1 / 60
	RivalPose.update(rig, 1 / 60, t, 1)
	local swing = (hip.C0 * hip.C1:Inverse()).LookVector.Y
	lowest, highest = math.min(lowest, swing), math.max(highest, swing)
	check(-placed("LeftLowerArm").RightVector.Z < -0.85, "The shield swung away while walking guarded")
end
check(highest - lowest > 0.3, "Walking guarded didn't step the legs")
-- The body's own walk animation is held off while the guard's up...
for _, d in rig:GetDescendants() do
	if d:IsA("Motor6D") then
		d.Transform = CFrame.identity -- (as Roblox has it; unset here)
	end
end
local elbow = rig.LeftLowerArm.LeftElbow
elbow.Transform = CFrame.Angles(0.8, 0, 0)
RivalPose.holdGuards()
check(select(2, elbow.Transform:ToAxisAngle()) < 0.05, "The walk animation still swings the shield arm")
-- ...and left alone once it drops.
rig:SetAttribute("GuardUntil", 0)
rig.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
for _ = 1, 60 do
	t += 1 / 60
	RivalPose.update(rig, 1 / 60, t, 1)
end
elbow.Transform = CFrame.Angles(0.8, 0, 0)
RivalPose.holdGuards()
check(select(2, elbow.Transform:ToAxisAngle()) > 0.75, "The walk animation stays held off after the guard drops")
print("PASS: " .. checks .. " fighter rig checks (the rival's body for everyone, posed cleanly, guarded walking)")
