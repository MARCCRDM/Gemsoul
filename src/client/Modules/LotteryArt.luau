-- Local, code-native presentation. Winning gear keeps its authored geometry.
local Players = game:GetService("Players")
local GemArt = require(script.Parent.GemArt)
local Art = {}
local INK = Color3.fromRGB(28, 39, 53)
local METAL = Color3.fromRGB(125, 145, 161)
local function part(model, size, frame, color, neon)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Size, p.CFrame, p.Color = size, frame, color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.Metal
	p.Parent = model
	return p
end
function Art.capsule(color)
	local model = Instance.new("Model")
	model.Name = "LaunchCapsule"
	part(model, Vector3.new(1.5, 2.3, 1.5), CFrame.new(), INK)
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local at = CFrame.Angles(0, angle, 0)
		part(model, Vector3.new(0.28, 2.6, 0.28), at * CFrame.new(0.65, 0, 0.65), METAL)
		part(model, Vector3.new(0.65, 1.7, 0.06), at * CFrame.new(0, 0, -0.78), color, true)
		part(model, Vector3.new(0.8, 0.07, 0.08), at * CFrame.new(0, 0.95, -0.79), Color3.fromRGB(249, 194, 101), true)
	end
	for _, y in { -1.4, 1.4 } do
		part(model, Vector3.new(2, 0.32, 2), CFrame.new(0, y, 0), METAL)
		part(model, Vector3.new(1.8, 0.08, 1.8), CFrame.new(0, y * 0.88, 0), color, true)
	end
	for i = 1, 20 do
		local angle = i * math.pi / 10
		part(
			model,
			Vector3.new(0.4, 0.05, 0.07),
			CFrame.new(math.cos(angle) * 2, -1.7, math.sin(angle) * 2) * CFrame.Angles(0, -angle, 0),
			color,
			true
		)
	end
	model:PivotTo(CFrame.Angles(0, 0.5, 0))
	return model
end
function Art.gear(slot)
	local character = Players.LocalPlayer.Character
	local equipment = character and character:FindFirstChild("GemsoulGear")
	local source = equipment and equipment:FindFirstChild(slot)
	if not source then
		return nil
	end
	local model = Instance.new("Model")
	for _, p in source:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local copy = p:Clone()
			for _, child in copy:GetDescendants() do
				if
					child:IsA("JointInstance")
					or child:IsA("WeldConstraint")
					or child:IsA("Script")
					or child:IsA("LocalScript")
				then
					child:Destroy()
				end
			end
			copy.Anchored, copy.CanCollide, copy.CanQuery = true, false, false
			copy.Parent = model
		end
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return nil
	end
	return model
end
function Art.show(parent, gem, slot, color, capsule)
	for _, child in parent:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "RewardArt"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(165, 181, 208)
	view.LightColor = Color3.fromRGB(255, 240, 211)
	view.LightDirection = Vector3.new(-0.6, -1, -0.8)
	view.ZIndex = parent.ZIndex + 1
	local model
	if gem then
		model = GemArt.model(gem, false)
		model:PivotTo(GemArt.pose(gem, 0.4))
	elseif not capsule then
		model = Art.gear(slot)
	end
	local fallback = model == nil
	model = model or Art.capsule(color)
	model.Parent = view
	local center, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = view
	view.CurrentCamera = camera
	view.Parent = parent
	-- Frame to the smaller viewport dimension so landscape and phone previews don't crop.
	local record = {
		View = view,
		Camera = camera,
		Center = center.Position,
		Radius = radius,
		Model = model,
		Fallback = fallback,
		Yaw = if gem or capsule or fallback then 0 else math.pi - 0.35,
	}
	Art.pose(record, 0, false)
	return record
end
function Art.pose(record, elapsed, calm)
	if not record or not record.View.Parent then
		return
	end
	local size = record.View.AbsoluteSize
	local aspect = if size.Y > 0 then math.max(0.25, size.X / size.Y) else 1
	local distance = record.Radius / math.sin(math.rad(17)) * 1.12 / math.min(1, aspect)
	local yaw = record.Yaw + (if calm then 0 else math.sin(elapsed * 0.55) * 0.28)
	local direction = Vector3.new(math.sin(yaw), 0.16, math.cos(yaw)).Unit
	local focus = record.Center + Vector3.new(0, if calm then 0 else math.sin(elapsed * 1.5) * record.Radius * 0.035, 0)
	record.Camera.CFrame = CFrame.lookAt(focus + direction * distance, focus)
end
return Art
