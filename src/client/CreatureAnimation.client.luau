-- Supplement the shared combat skeleton with creature-only detail joints.
-- Far creatures are reset and skipped; streaming arrivals get a rescan.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Shared.CreatureMotion)
local rigs = {}
local scanAt = 0

local function reset(rig)
	for _, entry in rig.Joints do
		if entry.Joint.Parent then entry.Joint.C0 = entry.Rest end
	end
	rig.Active = false
end

RunService.PreSimulation:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	if now >= scanAt then
		scanAt = now + 0.5
		local folder = workspace:FindFirstChild("Enemies")
		for _, model in if folder then folder:GetChildren() else {} do
			if not model:GetAttribute("CreatureShape") then continue end
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then continue end
			local rig = rigs[model]
			if not rig then
				rig = { Root = root, Humanoid = humanoid, Joints = {}, Known = {}, Phase = 0, Amount = 0 }
				rigs[model] = rig
			end
			for _, joint in model:GetDescendants() do
				if joint:IsA("Motor6D") and joint:GetAttribute("CreatureMotion") and not rig.Known[joint] then
					rig.Known[joint] = true
					table.insert(rig.Joints, { Joint = joint, Rest = joint:GetAttribute("CreatureRest"),
						Kind = joint:GetAttribute("CreatureMotion"), Side = joint:GetAttribute("CreatureSide") or 1 })
				end
			end
		end
		for model, rig in rigs do
			if not model:IsDescendantOf(workspace) or rig.Root.Parent == nil then
				reset(rig)
				rigs[model] = nil
			end
		end
	end
	local camera = workspace.CurrentCamera
	for model, rig in rigs do
		if not camera or rig.Humanoid.Health <= 0 or (rig.Root.Position - camera.CFrame.Position).Magnitude > 180 then
			if rig.Active then reset(rig) end
			continue
		end
		rig.Active = true
		local v = rig.Root.AssemblyLinearVelocity
		local speed = Vector2.new(v.X, v.Z).Magnitude
		local step = math.min(dt, 0.1)
		rig.Amount += (math.clamp(speed / 8, 0, 1) - rig.Amount) * (1 - math.exp(-10 * step))
		rig.Phase = (rig.Phase + speed * step * math.pi * 2 / (3.5 * model:GetScale())) % (math.pi * 2)
		local at = model:GetAttribute("ActionAt")
		for i = #rig.Joints, 1, -1 do
			local entry = rig.Joints[i]
			if not entry.Joint.Parent then
				rig.Known[entry.Joint] = nil
				table.remove(rig.Joints, i)
			else
				entry.Joint.C0 = entry.Rest * CFrame.Angles(Motion.angles(entry.Kind, now, rig.Phase, rig.Amount, entry.Side, at))
			end
		end
	end
end)
