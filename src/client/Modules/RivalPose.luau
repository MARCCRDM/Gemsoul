--[[
	Body language for the Arena rival. The server plays its walk, run and idle
	animations; this layers the fighting on top by bending its joints (Motor6D
	C0, set only on this client) from what the server says it is doing:

	  ActionKind   Slash, Heavy, Bolt, Nova, Buff, Dodge or Stagger
	  ActionStart  server time the wind-up began
	  ActionAt     server time the blow lands (or the cast releases)
	  ActionSide   1 or -1: which way a slash or a dodge goes
	  GuardUntil   server time its guard drops

	A slash winds the arm back and whips it across; a heavy goes overhead with
	both hands and slams down; a bolt gathers and thrusts the palm forward; a
	blast raises both arms and drives them into the ground; a buff throws the
	arms wide; a guard crosses the forearms in front of the face; a dodge
	tucks and leans; a stagger rocks it back.
]]
local RivalPose = {}

-- Joint -> the part that holds it (R15).
local JOINTS = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}
local JOINT_COUNT = 10
local FOLLOW = 0.32 -- how long a strike's follow-through holds, seconds

-- Angles are radians about the joint's X (positive swings a limb forward and
-- up, or leans the torso back), Y (twists left) and Z (positive raises the
-- right arm outward; negative the left).
local READY = {
	RightShoulder = { 0.35, 0, 0.1 },
	LeftShoulder = { 0.45, 0, -0.2 },
	RightElbow = { 0.7, 0, 0 },
	LeftElbow = { 0.8, 0, 0 },
}

local function lerp(a, b, t: number)
	local out = {}
	for joint, angles in a do
		local to = b[joint] or { 0, 0, 0 }
		out[joint] = {
			angles[1] + (to[1] - angles[1]) * t,
			angles[2] + (to[2] - angles[2]) * t,
			angles[3] + (to[3] - angles[3]) * t,
		}
	end
	for joint, angles in b do
		if not out[joint] then
			out[joint] = { angles[1] * t, angles[2] * t, angles[3] * t }
		end
	end
	return out
end

-- Wind-up and strike poses for each action; `s` mirrors a slash or dodge.
local function frames(kind: string, s: number)
	if kind == "Slash" then
		return {
			Waist = { 0, -0.55 * s, 0 },
			RightShoulder = { 2.3, 0, 0.7 * s },
			RightElbow = { 0.9, 0, 0 },
			LeftShoulder = { 0.6, 0, -0.3 },
			LeftElbow = { 0.9, 0, 0 },
		}, {
			Waist = { -0.15, 0.6 * s, 0 },
			RightShoulder = { 1.2, 0, -0.7 * s },
			RightElbow = { 0.15, 0, 0 },
			LeftShoulder = { 0.3, 0, -0.4 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Heavy" then
		return {
			Waist = { 0.3, -0.2, 0 },
			Neck = { 0.15, 0, 0 },
			RightShoulder = { 3.0, 0, 0.2 },
			LeftShoulder = { 3.0, 0, -0.2 },
			RightElbow = { 0.9, 0, 0 },
			LeftElbow = { 0.9, 0, 0 },
		}, {
			Waist = { -0.55, 0.1, 0 },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 0.7, 0, -0.15 },
			LeftShoulder = { 0.7, 0, 0.15 },
			RightElbow = { 0.1, 0, 0 },
			LeftElbow = { 0.1, 0, 0 },
			RightHip = { 0.5, 0, 0 },
			LeftHip = { -0.2, 0, 0 },
			RightKnee = { -0.6, 0, 0 },
			LeftKnee = { -0.3, 0, 0 },
		}
	elseif kind == "Bolt" then
		return {
			Waist = { 0, -0.4, 0 },
			RightShoulder = { 1.0, 0, 0.5 },
			RightElbow = { 1.5, 0, 0 },
			LeftShoulder = { 1.1, 0, -0.3 },
			LeftElbow = { 1.2, 0, 0 },
		}, {
			Waist = { -0.1, 0.25, 0 },
			RightShoulder = { 1.65, 0, -0.1 },
			RightElbow = { 0.05, 0, 0 },
			LeftShoulder = { 0.4, 0, -0.4 },
			LeftElbow = { 0.5, 0, 0 },
		}
	elseif kind == "Nova" then
		return {
			Waist = { 0.25, 0, 0 },
			Neck = { 0.35, 0, 0 },
			RightShoulder = { 2.7, 0, 0.6 },
			LeftShoulder = { 2.7, 0, -0.6 },
			RightElbow = { 0.3, 0, 0 },
			LeftElbow = { 0.3, 0, 0 },
		}, {
			Waist = { -0.6, 0, 0 },
			Neck = { -0.25, 0, 0 },
			RightShoulder = { 0.5, 0, 0.25 },
			LeftShoulder = { 0.5, 0, -0.25 },
			RightHip = { 0.7, 0, 0.1 },
			LeftHip = { 0.7, 0, -0.1 },
			RightKnee = { -1.0, 0, 0 },
			LeftKnee = { -1.0, 0, 0 },
		}
	elseif kind == "Buff" then
		return {
			RightShoulder = { 0.6, 0, 0.3 },
			LeftShoulder = { 0.6, 0, -0.3 },
			RightElbow = { 1.4, 0, 0 },
			LeftElbow = { 1.4, 0, 0 },
			Waist = { -0.2, 0, 0 },
		}, {
			Waist = { 0.2, 0, 0 },
			Neck = { 0.35, 0, 0 },
			RightShoulder = { 0.5, 0, 1.6 },
			LeftShoulder = { 0.5, 0, -1.6 },
			RightElbow = { 0.2, 0, 0 },
			LeftElbow = { 0.2, 0, 0 },
		}
	elseif kind == "Dodge" then
		local tuck = {
			Waist = { -0.5, 0, 0.35 * s },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 1.0, 0, -0.2 },
			LeftShoulder = { 1.0, 0, 0.2 },
			RightElbow = { 1.3, 0, 0 },
			LeftElbow = { 1.3, 0, 0 },
			RightHip = { 1.0, 0, 0 },
			LeftHip = { 1.0, 0, 0 },
			RightKnee = { -1.3, 0, 0 },
			LeftKnee = { -1.3, 0, 0 },
		}
		return tuck, tuck
	elseif kind == "Stagger" then
		local reel = {
			Waist = { 0.45, 0.2, 0 },
			Neck = { 0.4, 0, 0 },
			RightShoulder = { 0.4, 0, 0.9 },
			LeftShoulder = { 0.4, 0, -0.9 },
			RightKnee = { -0.4, 0, 0 },
			LeftKnee = { -0.4, 0, 0 },
		}
		return reel, reel
	end
	return nil, nil
end

local GUARD = {
	Waist = { -0.15, 0, 0 },
	Neck = { -0.1, 0, 0 },
	RightShoulder = { 1.45, 0, -0.55 },
	LeftShoulder = { 1.45, 0, 0.55 },
	RightElbow = { 1.7, 0, 0 },
	LeftElbow = { 1.7, 0, 0 },
	RightHip = { 0.25, 0, 0 },
	RightKnee = { -0.35, 0, 0 },
}

-- The pose for these attributes at server time `t` (pure, for testing):
-- { [joint] = { x, y, z } }, plus how snappily to move into it.
function RivalPose.pose(a, t: number): ({ [string]: { number } }, number)
	local kind, start, at = a.ActionKind, a.ActionStart, a.ActionAt
	if type(kind) == "string" and type(start) == "number" and type(at) == "number" then
		local windup, strike = frames(kind, if a.ActionSide == -1 then -1 else 1)
		if windup and t >= start then
			if t < at then
				-- Ease into the wind-up as it builds.
				local p = math.clamp((t - start) / math.max(0.05, at - start), 0, 1)
				return lerp(READY, windup, math.min(1, p * 1.6)), 14
			end
			local hold = if kind == "Dodge"
				then 0.4
				elseif kind == "Stagger" then 0.45
				elseif kind == "Buff" then 0.6
				else FOLLOW
			if t < at + hold then
				return strike, 30 -- the blow itself snaps through
			end
		end
	end
	if type(a.GuardUntil) == "number" and t < a.GuardUntil then
		return GUARD, 22
	end
	return READY, 10
end

-- [model] = { Motors = { [joint] = { Motor, C0 } }, Angles = {...} }
-- (Not weak-keyed: a dropped entry would be rebuilt mid-pose.)
local rigs = {}

-- A joint's resting C0, remembered on the joint itself the first time it's
-- seen, so a re-scan never mistakes an already-bent joint for its rest pose
-- (which would stack every pose on top of the last).
local function restC0(motor: Motor6D): CFrame
	local rest = motor:GetAttribute("RestC0")
	if typeof(rest) ~= "CFrame" then
		rest = motor.C0
		motor:SetAttribute("RestC0", rest)
	end
	return rest
end

-- Its joints. With streaming on, the body parts can arrive after the model
-- itself, so any joint not found yet is looked for again every half second.
local function rigOf(model: Model)
	local rig = rigs[model]
	if not rig then
		rig = { Motors = {}, Angles = {}, Found = 0, NextScan = 0 }
		rigs[model] = rig
	end
	local now = os.clock()
	if rig.Found < JOINT_COUNT and now >= rig.NextScan then
		rig.NextScan = now + 0.5
		for joint, partName in JOINTS do
			local entry = rig.Motors[joint]
			if not entry or entry.Motor.Parent == nil then
				local part = model:FindFirstChild(partName)
				local motor = part and part:FindFirstChild(joint)
				if motor and motor:IsA("Motor6D") then
					rig.Motors[joint] = { Motor = motor, C0 = restC0(motor) }
					rig.Angles[joint] = { 0, 0, 0 }
				end
			end
		end
		rig.Found = 0
		for _ in rig.Motors do
			rig.Found += 1
		end
	end
	return rig
end

local ATTRIBUTES = { "ActionKind", "ActionStart", "ActionAt", "ActionSide", "GuardUntil" }

-- Call every frame with the rival's model.
function RivalPose.update(model: Model?, dt: number)
	for known in rigs do
		if not known.Parent then
			rigs[known] = nil -- gone: forget it
		end
	end
	if not model or not model.Parent then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local rig = rigOf(model)
	local attrs = {}
	for _, name in ATTRIBUTES do
		attrs[name] = model:GetAttribute(name)
	end
	local target, speed = RivalPose.pose(attrs, workspace:GetServerTimeNow())
	local alpha = 1 - math.exp(-speed * math.min(dt, 0.1))
	for joint, entry in rig.Motors do
		local angles = rig.Angles[joint]
		local to = target[joint] or { 0, 0, 0 }
		for i = 1, 3 do
			angles[i] += (to[i] - angles[i]) * alpha
		end
		entry.Motor.C0 = entry.C0 * CFrame.Angles(angles[1], angles[2], angles[3])
	end
end

return RivalPose
