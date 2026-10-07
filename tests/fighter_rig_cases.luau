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
print("PASS: " .. checks .. " fighter rig checks (the rival's body for everyone, posed cleanly)")
