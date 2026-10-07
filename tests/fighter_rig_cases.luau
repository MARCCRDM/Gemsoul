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
-- The shield faces straight ahead, the body square to the front. (Mounted
-- as Equipment mounts it on a FistGrip body: on the outside of the left
-- forearm, turned 110 degrees; its face is the mount's -Z.)
local SHIELD_MOUNT = CFrame.Angles(0, math.rad(110), 0)
local function shieldFace()
	return (placed("LeftLowerArm") * SHIELD_MOUNT).LookVector
end
local face = shieldFace()
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
	check(shieldFace().Z < -0.85, "The shield swung away while walking guarded")
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
-- The blows: the sword (held as Equipment holds it on a FistGrip body:
-- gripped just below the hand, turned 120 degrees, about 2.8 studs to the
-- tip) cuts a wide arc in front of the body, the way the slash drawn along it
-- shows; RivalPose marks the cut itself (when BladeTrails draws it).
local function tipNow()
	local chain = { RightUpperArm = { "UpperTorso", "RightShoulder" }, RightLowerArm = { "RightUpperArm", "RightElbow" },
		RightHand = { "RightLowerArm", "RightWrist" } }
	local function at(name)
		if name == "UpperTorso" then
			return placed("UpperTorso")
		end
		local link = chain[name]
		local m = rig[name][link[2]]
		return at(link[1]) * m.C0 * m.C1:Inverse()
	end
	local root = rig.HumanoidRootPart.CFrame
	return root:PointToObjectSpace((at("RightHand") * CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-120), 0, 0) * CFrame.new(0, 2.8, 0)).Position)
end
local function blow(kind, side)
	rig:SetAttribute("GuardUntil", 0)
	rig:SetAttribute("ActionKind", nil)
	for _ = 1, 60 do
		t += 1 / 60
		RivalPose.update(rig, 1 / 60, t, 1)
	end
	local at = t + 0.4
	rig:SetAttribute("ActionKind", kind)
	rig:SetAttribute("ActionSide", side)
	rig:SetAttribute("ActionStart", t)
	rig:SetAttribute("ActionAt", at)
	local path, cutting, early = {}, 0, false
	while t < at + 0.35 do
		t += 1 / 60
		RivalPose.update(rig, 1 / 60, t, 1)
		if RivalPose.striking(rig) then
			cutting += 1
			table.insert(path, tipNow())
			early = early or t < at - 0.05
		end
	end
	check(not early, kind .. ": marked as cutting during its wind-up")
	check(cutting >= 4, kind .. ": the cut wasn't marked")
	return path
end
for _, side in { 1, -1 } do
	local path = blow("Slash", side)
	local first, last, ahead = path[1], path[#path], 0
	for _, p in path do
		ahead = math.min(ahead, p.Z)
		check(p.Y > 0 and p.Y < 4, "Slash: the blade left the body's height band (" .. p.Y .. ")")
	end
	check(ahead < -2.5, "Slash: the cut never swept in front of the body")
	check((last.X - first.X) * side < -2.5, "Slash: the cut went the wrong way across (side " .. side .. ")")
end
do
	local path = blow("Heavy", 1)
	local high, last = -math.huge, path[#path]
	for _, p in path do
		high = math.max(high, p.Y)
	end
	check(high > 3.5, "Heavy: the blow didn't come over the top")
	check(last.Y < 1 and last.Z < -2, "Heavy: the blow didn't slam down in front")
end
print("PASS: " .. checks .. " fighter rig checks (the rival's body for everyone, posed cleanly, guarded walking, blade arcs)")
