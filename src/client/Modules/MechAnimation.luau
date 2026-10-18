-- Animate all nearby quarry mechs, including those piloted by other players,
-- and draw each one gliding between the server's steps (it's anchored, and
-- moved by the server: Server OutpostVehicles).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Motion = require(ReplicatedStorage.Shared.MechMotion)
local Seating = require(ReplicatedStorage.Shared.Seating)
local TAG = "OutpostMech"
local RANGE = 300 -- studs from the camera a mech is animated and glided within
local active = {}
local pending = {}

local function remove(model)
	local connection = pending[model]
	if connection then
		connection:Disconnect()
	end
	pending[model], active[model] = nil, nil
end

local function register(model)
	if active[model] or not model:IsA("Model") then
		return
	end
	local function ready()
		if not model:IsDescendantOf(workspace) or not CollectionService:HasTag(model, TAG) then
			return false
		end
		local root, seat = model:FindFirstChild("Chassis"), model:FindFirstChild("Seat")
		if not root or not seat then
			return false
		end
		local joints = {}
		for _, item in model:GetDescendants() do
			if item:IsA("Motor6D") and item:GetAttribute("MechRest") then
				joints[item.Name] = { Joint = item, Inverse = item:GetAttribute("MechRest"):Inverse() }
			end
		end
		for _, name in
			{
				"Waist",
				"LeftHip",
				"LeftKnee",
				"LeftAnkle",
				"RightHip",
				"RightKnee",
				"RightAnkle",
				"LeftShoulder",
				"LeftElbow",
				"RightShoulder",
				"RightElbow",
			}
		do
			if not joints[name] then
				return false
			end
		end
		if seat:GetAttribute("OutpostMachine") == "Mole" and not joints.ToolRotor then
			return false
		end
		active[model] = {
			Root = root,
			Seat = seat,
			Joints = joints,
			State = Motion.new(),
			Scale = model:GetAttribute("MechScale") or 1,
		}
		if pending[model] then
			pending[model]:Disconnect()
			pending[model] = nil
		end
		return true
	end
	if not ready() and not pending[model] then
		pending[model] = model.DescendantAdded:Connect(function()
			task.defer(ready)
		end)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
for _, model in CollectionService:GetTagged(TAG) do
	register(model)
end
-- A mining strike (OutpostServer sets MechStrikeStart and MechStrikeTarget
-- on the mech): the right arm winds up overhead and slams down on the rock,
-- or, on the drill mech, pulls back and drives the drill in, spinning. It
-- plays over the walk, then hands back to it.
-- Keys: { time, right shoulder, right elbow, waist yaw, waist pitch, left shoulder }
-- (The mech faces -Z: a shoulder's positive turn swings the arm forward and
-- up, an elbow's folds the forearm the way a human's does.)
local SLAM = {
	{ 0, 0, -0.18, 0, 0, 0 },
	{ 0.18, 3.25, 1.3, -0.32, 0.12, 0.55 }, -- overhead, cocked behind, twisted back
	{ 0.27, 0.6, -0.05, 0.3, -0.3, 0.75 }, -- down through the rock, leaning in
	{ 0.42, 0.62, -0.08, 0.26, -0.26, 0.7 },
}
local THRUST = {
	{ 0, 0, -0.18, 0, 0, 0 },
	{ 0.14, -0.6, 1.5, -0.22, 0.06, 0.4 }, -- drill drawn back to the hip
	{ 0.24, 1.4, 0.05, 0.22, -0.14, 0.6 }, -- punched straight in
	{ 0.55, 1.35, 0.03, 0.2, -0.12, 0.6 }, -- grinding
}
local STRIKE_END = 0.8 -- back to walking by then
local DUST, SPARK, DRILL_SPARK =
	Color3.fromRGB(150, 140, 130), Color3.fromRGB(255, 200, 110), Color3.fromRGB(120, 230, 255)

local function sample(keys, t: number): { number }
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local k = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
			k = k * k * (3 - 2 * k)
			local out = {}
			for j = 2, #a do
				out[j - 1] = a[j] + (b[j] - a[j]) * k
			end
			return out
		end
	end
	local last = keys[#keys]
	return { last[2], last[3], last[4], last[5], last[6] }
end

-- The strike's pose blended over the walk's (in place), at `t` seconds in.
local function strike(poses, t: number, drill: boolean, now: number)
	local v = sample(if drill then THRUST else SLAM, t)
	local hold = if drill then THRUST[#THRUST][1] else SLAM[#SLAM][1]
	local weight = math.clamp(t / 0.05, 0, 1) * (1 - math.clamp((t - hold) / (STRIKE_END - hold), 0, 1))
	local shake = if drill and t > 0.24 and t < hold then math.sin(now * 90) * 0.03 else 0
	local target = {
		RightShoulder = CFrame.Angles(v[1] + shake, 0, 0.08),
		RightElbow = CFrame.Angles(v[2], 0, 0),
		Waist = CFrame.Angles(v[4], v[3], 0),
		LeftShoulder = CFrame.Angles(v[5], 0, -0.08),
		LeftElbow = CFrame.Angles(-0.18 + v[5] * 1.2, 0, 0),
	}
	for name, cf in target do
		poses[name] = poses[name]:Lerp(cf, weight)
	end
	if drill then
		poses.ToolRotor = CFrame.Angles(0, now * 40, 0)
	end
end

-- Where it lands: dust and sparks thrown up, a shockwave of dust rolling
-- out over the ground, and a kick for anyone close (the pilot most).
local function impact(at: Vector3, scale: number, drill: boolean, distance: number)
	local ok, Fx = pcall(require, script.Parent.CombatFx)
	if not ok then
		return
	end
	Fx.burst(at, DUST, "Smoke", 1.5 * scale)
	Fx.burst(at, if drill then DRILL_SPARK else SPARK, "Sparks", 1.4 * scale)
	Fx.flash(at, if drill then DRILL_SPARK else SPARK, 4, 20 * scale, 0.25)
	local ring = Instance.new("Part")
	ring.Name = "MechShockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material, ring.Color, ring.Transparency = Enum.Material.SmoothPlastic, DUST, 0.3
	ring.Size = Vector3.new(0.25, 3, 3) * scale
	ring.CFrame = CFrame.new(at - Vector3.new(0, 1.6 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.08, 18, 18) * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.6)
	if distance < 60 then
		Fx.shake(0.035 * (1 - distance / 60), 0.3)
	end
end

-- The server moves a mech in steps, which reach this screen unevenly. Between
-- them it's drawn carrying on from the latest (MechPosition, and MechMotion:
-- heading, speed, turn rate) for a moment, easing out any difference; once
-- it stops it's put exactly where the server has it, and left there.
local GLIDE = 18 -- how quickly the drawn mech catches up (per second)
local AHEAD = 0.25 -- seconds it carries on from a step before waiting for the next
local SNAP = 12 -- studs off, it jumps there
local function glide(dt: number)
	local camera = workspace.CurrentCamera
	local clock = os.clock()
	for model, rig in active do
		local position, motion = model:GetAttribute("MechPosition"), model:GetAttribute("MechMotion")
		if typeof(position) ~= "Vector3" or typeof(motion) ~= "Vector3" then
			continue
		end
		if position ~= rig.Position or motion ~= rig.Motion then
			rig.Position, rig.Motion, rig.Heard, rig.Settled = position, motion, clock, false
		end
		if rig.Settled then
			continue
		end
		if camera and (position - camera.CFrame.Position).Magnitude > RANGE then
			rig.Shown = nil -- (far off, the server's own steps will do)
			continue
		end
		local ahead = math.min(clock - rig.Heard, AHEAD)
		local heading = CFrame.Angles(0, motion.X + motion.Z * ahead, 0)
		local goal = CFrame.new(position + heading.LookVector * (motion.Y * ahead)) * heading
		local shown = rig.Shown or rig.Root.CFrame
		if (shown.Position - goal.Position).Magnitude > SNAP then
			shown = goal
		else
			shown = shown:Lerp(goal, 1 - math.exp(-GLIDE * dt))
		end
		if
			motion.Y == 0
			and motion.Z == 0
			and (shown.Position - goal.Position).Magnitude < 0.02
			and shown.LookVector:Dot(goal.LookVector) > 0.99999
		then
			shown, rig.Settled = goal, true
		end
		rig.Shown = shown
		rig.Root.CFrame = shown
	end
end
-- (Before the camera follows it.)
RunService:BindToRenderStep("MechGlide", Enum.RenderPriority.Camera.Value - 1, glide)

RunService.PreSimulation:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = workspace:GetServerTimeNow()
	for model, rig in active do
		if not rig.Root:IsDescendantOf(workspace) then
			remove(model)
			continue
		end
		if (rig.Root.Position - camera.CFrame.Position).Magnitude > RANGE then
			continue
		end
		local occupied = Seating.occupant(rig.Seat) ~= nil
		-- How fast the server moves it (forward, and turning): it's anchored,
		-- so it has no velocity of its own.
		local motion = model:GetAttribute("MechMotion")
		local speed = if typeof(motion) == "Vector3" then motion.Y / rig.Scale else 0
		local turn = if typeof(motion) == "Vector3" then motion.Z else 0
		Motion.step(rig.State, dt, speed, turn, occupied)
		local poses = Motion.pose(rig.State, rig.Scale, now, occupied)
		local struck = model:GetAttribute("MechStrikeStart")
		local t = if type(struck) == "number" then now - struck else math.huge
		if t >= 0 and t < STRIKE_END then
			local drill = rig.Seat:GetAttribute("OutpostMachine") == "Mole"
			strike(poses, t, drill, now)
			local landed = if drill then THRUST[3][1] else SLAM[3][1]
			local target = model:GetAttribute("MechStrikeTarget")
			if t >= landed and rig.Landed ~= struck and typeof(target) == "Vector3" then
				rig.Landed = struck
				impact(target, rig.Scale, drill, (target - camera.CFrame.Position).Magnitude)
			end
		end
		for name, joint in rig.Joints do
			joint.Joint.Transform = joint.Inverse * poses[name]
		end
	end
end)

return {}
