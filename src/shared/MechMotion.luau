-- Cosmetic locomotion from observed travel, so spectators see the same walking
-- behaviour without remote events. Two-bone IK keeps boots level and above ground.
local MechMotion = {}

function MechMotion.new()
	return { Phase = 0, Weight = 0 }
end

function MechMotion.step(state, dt: number, speed: number, turn: number, occupied: boolean)
	dt = math.clamp(dt, 0, 0.1)
	local travel = if occupied then math.max(math.abs(speed), math.abs(turn) * 3) else 0
	local target = math.clamp(travel / 5, 0, 1)
	state.Weight += (target - state.Weight) * (1 - math.exp(-dt * 9))
	local direction = if speed < -0.25 then -1 else 1
	state.Phase = (state.Phase + travel / 12 * math.pi * 2 * dt * direction) % (math.pi * 2)
	return state
end

function MechMotion.pose(state, scale: number, time: number, occupied: boolean)
	local poses = {}
	local w, phase = state.Weight, state.Phase
	poses.Waist = CFrame.new(0, math.abs(math.sin(phase)) * 0.1 * w * scale, 0)
		* CFrame.Angles(-0.035 * w, math.sin(phase) * 0.025 * w, 0)
	for index, side in { "Left", "Right" } do
		local p = phase + (index - 1) * math.pi
		local z = math.cos(p) * 2.1 * w
		local down = 6.8 - math.max(0, math.sin(p)) * 1.15 * w
		local length = math.sqrt(down * down + z * z)
		local knee = -2 * math.acos(math.clamp(length / 7.2, 0.05, 1))
		local hip = -math.atan2(z, down) - knee / 2
		poses[side .. "Hip"] = CFrame.Angles(hip, 0, 0)
		poses[side .. "Knee"] = CFrame.Angles(knee, 0, 0)
		poses[side .. "Ankle"] = CFrame.Angles(-hip - knee, 0, 0)
		local sign = if index == 1 then -1 else 1
		poses[side .. "Shoulder"] = CFrame.Angles(-math.cos(p) * 0.2 * w, 0, sign * 0.08)
		poses[side .. "Elbow"] = CFrame.Angles(-0.18 - math.max(0, math.sin(p)) * 0.12 * w, 0, 0)
	end
	poses.ToolRotor = CFrame.Angles(0, if occupied then time * 5 else 0, 0)
	return poses
end

return MechMotion
