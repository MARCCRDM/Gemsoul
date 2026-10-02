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
	local brass = Color3.fromRGB(176, 126, 66)
	local core = part(model, Vector3.new(0.9, 0.9, 0.9), CFrame.Angles(0.5, 0.6, 0.7), color, true)
	core.Name = "ResonanceCore"
	for index = 0, 5 do
		local at = CFrame.Angles(0, index * math.pi / 3, 0)
		local shell = part(model, Vector3.new(0.94, 2.05, 0.22), at * CFrame.new(0, 0, -0.86), INK)
		shell:SetAttribute("VaultPanel", "Shell")
		for _, x in { -0.4, 0.4 } do
			local rail = part(model, Vector3.new(0.09, 2.3, 0.16), at * CFrame.new(x, 0, -1), brass)
			rail:SetAttribute("VaultPanel", "Shell")
		end
		local inset = part(model, Vector3.new(0.55, 1.45, 0.06), at * CFrame.new(0, 0, -1), Color3.fromRGB(44, 59, 73))
		inset:SetAttribute("VaultPanel", "Shell")
		local seam = part(model, Vector3.new(0.06, 1.25, 0.06), at * CFrame.new(0, 0, -1.05), color, true)
		seam:SetAttribute("VaultPanel", "Shell")
		for _, y in { -1.15, 1.15 } do
			local crown = part(model, Vector3.new(1.12, 0.25, 0.28), at * CFrame.new(0, y, -0.85), brass)
			if y > 0 then
				crown:SetAttribute("VaultPanel", "Crown")
			end
		end
	end
	for i = 1, 24 do
		local angle = i * math.pi / 12
		local at = CFrame.new(math.cos(angle) * 1.5, -1.5, math.sin(angle) * 1.5) * CFrame.Angles(0, -angle, 0)
		part(model, Vector3.new(0.42, 0.15, 0.34), at, METAL)
		part(model, Vector3.new(0.2, 0.025, 0.06), at * CFrame.new(0, 0.1, 0), color, true)
	end
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
	view.Ambient = Color3.fromRGB(123, 147, 179)
	view.LightColor = Color3.fromRGB(255, 235, 201)
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
	local doors = {}
	if fallback then
		for _, piece in model:GetChildren() do
			local kind = piece:GetAttribute("VaultPanel")
			if kind then
				table.insert(doors, {
					Part = piece,
					Closed = piece.CFrame,
					Direction = if kind == "Crown" then Vector3.new(0, 1, 0) else piece.CFrame.LookVector,
				})
			end
		end
	end
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
		Doors = doors,
		Yaw = if gem or capsule or fallback then 0 else math.pi - 0.35,
	}
	Art.pose(record, 0, false)
	return record
end
function Art.pose(record, elapsed, calm)
	if not record or not record.View.Parent then
		return
	end
	local opening = if calm then 0 else math.clamp(record.Opening or 0, 0, 1)
	for _, door in record.Doors do
		door.Part.CFrame = door.Closed + door.Direction * (opening * 0.7)
	end
	local size = record.View.AbsoluteSize
	if calm and record.LastCalm and record.LastWidth == size.X and record.LastHeight == size.Y then
		return
	end
	record.LastCalm, record.LastWidth, record.LastHeight = calm, size.X, size.Y
	local aspect = if size.Y > 0 then math.max(0.25, size.X / size.Y) else 1
	local distance = record.Radius / math.sin(math.rad(17)) * 1.12 * (1 + opening * 0.1) / math.min(1, aspect)
	local yaw = record.Yaw + (if calm then 0 else math.sin(elapsed * 0.55) * 0.28)
	local direction = Vector3.new(math.sin(yaw), 0.16, math.cos(yaw)).Unit
	local focus = record.Center + Vector3.new(0, if calm then 0 else math.sin(elapsed * 1.5) * record.Radius * 0.035, 0)
	record.Camera.CFrame = CFrame.lookAt(focus + direction * distance, focus)
end
return Art
