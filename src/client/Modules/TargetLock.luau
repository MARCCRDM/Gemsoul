-- Soft camera tracking yields to deliberate look input. Selection is local; hits remain server-validated.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Rules = require(ReplicatedStorage.Shared.TargetLockRules)
local player = Players.LocalPlayer
local Lock = {}
local active, manualUntil, nextScan = false, 0, 0
local state, candidates = Rules.new(), {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local outline = Instance.new("Highlight")
outline.Name = "CombatTargetLock"
outline.FillTransparency = 1
outline.OutlineTransparency = 0.25
outline.OutlineColor = Color3.fromRGB(101, 210, 228)
outline.DepthMode = Enum.HighlightDepthMode.Occluded
outline.Enabled = false
outline.Parent = workspace
local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end
local function eligible(model)
	local ownRoot, root = rootOf(player.Character), rootOf(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if
		not model:IsDescendantOf(workspace)
		or not ownRoot
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or model == player.Character
		or CollectionService:HasTag(model, "Vendor")
		or model:FindFirstChildOfClass("ForceField")
		or not Combat.canFight(root.Position)
	then
		return false
	end
	local opponent = Players:GetPlayerFromCharacter(model)
	if opponent then
		local sameTeam = player.Team ~= nil
			and player.Team == opponent.Team
			and not player.Neutral
			and not opponent.Neutral
		return not player.Character:FindFirstChildOfClass("ForceField")
			and Actions.canPvP(
				player,
				opponent,
				Combat.inArena(ownRoot.Position),
				Combat.inArena(root.Position),
				player:GetAttribute("PvPEnabled"),
				opponent:GetAttribute("PvPEnabled"),
				sameTeam
			)
	end
	return model:GetAttribute("Enemy") ~= nil
end
local function pointOf(model)
	local root = rootOf(model)
	return root and root.Position + Vector3.new(0, math.min(1, root.Size.Y * 0.25), 0)
end
local function visible(model, point)
	local camera = workspace.CurrentCamera
	local screen, onScreen = camera:WorldToViewportPoint(point)
	if not onScreen or screen.Z <= 0 then
		return false
	end
	params.FilterDescendantsInstances = { player.Character, camera, workspace:FindFirstChild("CombatFx") }
	local result = workspace:Raycast(camera.CFrame.Position, point - camera.CFrame.Position, params)
	return result == nil or result.Instance:IsDescendantOf(model)
end
function Lock.reset()
	state, candidates, nextScan, manualUntil = Rules.new(), {}, 0, 0
	outline.Adornee, outline.Enabled = nil, false
end
function Lock.setActive(value)
	if active and not value then
		Lock.reset()
	end
	active = value
end
function Lock.target()
	local model = state.Target
	local point = model and pointOf(model)
	if not active or not point or not eligible(model) or not visible(model, point) then
		return nil
	end
	return model
end
function Lock.point()
	local model = Lock.target()
	return model and pointOf(model)
end
UserInputService.InputChanged:Connect(function(input, processed)
	if processed then
		return
	end
	if
		input.UserInputType == Enum.UserInputType.Touch
		or (input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.1)
	then
		manualUntil = os.clock() + 0.18
	end
end)
RunService:BindToRenderStep("SagaTargetLock", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not active then
		return
	end
	local camera, ownRoot = workspace.CurrentCamera, rootOf(player.Character)
	if not camera or not ownRoot then
		Lock.reset()
		return
	end
	local now = os.clock()
	if UserInputService.MouseEnabled and UserInputService:GetMouseDelta().Magnitude > 0.5 then
		manualUntil = now + 0.18
	end
	if now >= nextScan then
		table.clear(candidates)
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			for _, model in enemies:GetChildren() do
				table.insert(candidates, model)
			end
		end
		for _, opponent in Players:GetPlayers() do
			if opponent.Character and opponent ~= player then
				table.insert(candidates, opponent.Character)
			end
		end
		nextScan = now + 0.1
	end
	local records = {}
	for _, model in candidates do
		local point = pointOf(model)
		if point and eligible(model) then
			local delta = point - camera.CFrame.Position
			local distance = (point - ownRoot.Position).Magnitude
			if delta.Magnitude > 0.01 and distance <= Rules.Range then
				local facing = camera.CFrame.LookVector:Dot(delta.Unit)
				if facing >= Rules.RetainDot then
					table.insert(records, {
						Target = model,
						Distance = distance,
						Facing = facing,
						Allowed = true,
						Visible = visible(model, point),
					})
				end
			end
		end
	end
	local target = Rules.update(state, records, now, now < manualUntil)
	outline.Adornee, outline.Enabled = target, target ~= nil
	if target and now >= manualUntil then
		local point = pointOf(target)
		if point then
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, point), 1 - math.exp(-dt * 7))
		end
	end
end)
return Lock
