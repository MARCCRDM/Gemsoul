-- Animate all nearby quarry mechs, including those piloted by other players.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Motion = require(ReplicatedStorage.Shared.MechMotion)
local TAG = "OutpostMech"
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
		if (rig.Root.Position - camera.CFrame.Position).Magnitude > 300 then
			continue
		end
		local occupied = rig.Seat.Occupant ~= nil
		local speed = rig.Root.AssemblyLinearVelocity:Dot(rig.Root.CFrame.LookVector) / rig.Scale
		Motion.step(rig.State, dt, speed, rig.Root.AssemblyAngularVelocity.Y, occupied)
		local poses = Motion.pose(rig.State, rig.Scale, now, occupied)
		for name, joint in rig.Joints do
			joint.Joint.Transform = joint.Inverse * poses[name]
		end
	end
end)

return {}
