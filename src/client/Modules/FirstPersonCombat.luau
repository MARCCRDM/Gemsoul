-- Local camera presentation only; the real equipped geometry and all damage stay on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local View = {}
local saved, model, gear, connection, removalConnection
local pieces, hidden = {}, {}
local raised, charge, swingAt, swingSide = 0, 0, -10, "Right"
local cursorFree = false
local fireAt, smoothedRaised, smoothedCharge = -10, 0, 0
local dirty = true
local function clearModel()
	if model then
		model:Destroy()
	end
	model, gear = nil, nil
	table.clear(pieces)
end
local function rebuild(character, equipment)
	clearModel()
	gear = equipment
	model = Instance.new("Model")
	model.Name = "FirstPersonLoadout"
	model.Parent = workspace.CurrentCamera
	for _, slot in { "Weapon", "Shield", "Gloves" } do
		local source = equipment:FindFirstChild(slot)
		if source then
			for _, part in source:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local weld = part:FindFirstChildWhichIsA("WeldConstraint")
					local anchor = weld and weld.Part0
					local left = anchor and string.find(anchor.Name, "Left") ~= nil
					if slot == "Shield" then
						left = true
					end
					anchor = anchor
						or source:FindFirstChild("RightGrip")
						or character:FindFirstChild("RightHand")
						or character:FindFirstChild("Right Arm")
					if anchor then
						local copy = part:Clone()
						-- Enchantment particles, beams and lights stay on the real
						-- gear (others see them); up against the camera they'd
						-- only smear across the view.
						for _, descendant in copy:GetDescendants() do
							if
								descendant:IsA("JointInstance")
								or descendant:IsA("WeldConstraint")
								or descendant:IsA("Script")
								or descendant:IsA("LocalScript")
								or descendant:IsA("ParticleEmitter")
								or descendant:IsA("Beam")
								or descendant:IsA("Light")
							then
								descendant:Destroy()
							end
						end
						copy.Anchored, copy.CanCollide, copy.CanTouch, copy.CanQuery, copy.CastShadow =
							true, false, false, false, false
						copy.LocalTransparencyModifier = 0
						-- Preserve authored neon and colors; give metal panels a restrained highlight.
						if copy.Material == Enum.Material.Metal then
							copy.Reflectance = math.max(copy.Reflectance, 0.08)
						end
						copy.Size *= 0.65
						copy.Parent = model
						local offset = anchor.CFrame:ToObjectSpace(part.CFrame)
						table.insert(
							pieces,
							{ Part = copy, Left = left, Offset = CFrame.new(offset.Position * 0.65) * offset.Rotation }
						)
					end
				end
			end
		end
	end
end
function View.setPose(blocking, progress)
	raised = if blocking then 1 else 0
	charge = math.clamp(progress or 0, 0, 1)
end
function View.swing(side)
	swingAt, swingSide = os.clock(), side or "Right"
end
function View.fire()
	fireAt = os.clock()
end
function View.setCursorFree(value)
	cursorFree = value
end
function View.stop()
	if not saved then
		return
	end
	RunService:UnbindFromRenderStep("SagaFirstPerson")
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if removalConnection then
		removalConnection:Disconnect()
		removalConnection = nil
	end
	clearModel()
	for part, transparency in hidden do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(hidden)
	player.CameraMaxZoomDistance = saved.Max
	player.CameraMinZoomDistance = saved.Min
	player.CameraMode = saved.Mode
	UserInputService.MouseBehavior, UserInputService.MouseIconEnabled = saved.Mouse, saved.Icon
	if saved.Camera.Parent then
		saved.Camera.FieldOfView = saved.Fov
	end
	saved = nil
	cursorFree, raised, charge = false, 0, 0
	fireAt, smoothedRaised, smoothedCharge, swingAt = -10, 0, 0, -10
end
function View.start()
	if saved then
		return
	end
	local camera = workspace.CurrentCamera
	saved = {
		Mode = player.CameraMode,
		Min = player.CameraMinZoomDistance,
		Max = player.CameraMaxZoomDistance,
		Camera = camera,
		Fov = camera.FieldOfView,
		Mouse = UserInputService.MouseBehavior,
		Icon = UserInputService.MouseIconEnabled,
	}
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 0.5
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.FieldOfView = 75
	local function track(part)
		dirty = true
		if part:IsA("BasePart") and hidden[part] == nil then
			hidden[part] = part.LocalTransparencyModifier
		end
	end
	local character = player.Character
	if character then
		for _, part in character:GetDescendants() do
			track(part)
		end
		connection = character.DescendantAdded:Connect(track)
		removalConnection = character.DescendantRemoving:Connect(function(part)
			dirty = true
			if hidden[part] ~= nil then
				part.LocalTransparencyModifier = hidden[part]
				hidden[part] = nil
			end
		end)
	end
	RunService:BindToRenderStep("SagaFirstPerson", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local current = workspace.CurrentCamera
		for part in hidden do
			if part.Parent then
				part.LocalTransparencyModifier = 1
			end
		end
		if UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = if cursorFree
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = cursorFree
		end
		local equipment = character and character:FindFirstChild("GemsoulGear")
		if equipment and (dirty or equipment ~= gear or not model or model.Parent ~= current) then
			rebuild(character, equipment)
			dirty = false
		end
		if not equipment and model then
			clearModel()
		end
		local elapsed = os.clock() - swingAt
		local swing = if elapsed >= 0 and elapsed < 0.34 then math.sin(elapsed / 0.34 * math.pi) else 0
		local direction = if swingSide == "Left" then -1 else 1
		local breathe = math.sin(os.clock() * 2) * 0.012
		smoothedRaised += (raised - smoothedRaised) * (1 - math.exp(-(dt or 1 / 60) * 18))
		smoothedCharge += (charge - smoothedCharge) * (1 - math.exp(-(dt or 1 / 60) * 22))
		local fireElapsed = os.clock() - fireAt
		local recoil = if fireElapsed >= 0 and fireElapsed < 0.24
			then math.sin(math.min(1, fireElapsed / 0.045) * math.pi / 2) * math.exp(-fireElapsed * 16)
			else 0
		for _, piece in pieces do
			local pose = if piece.Left
				then CFrame.new(-0.72 + smoothedRaised * 0.4, -0.8 + smoothedRaised * 0.45 + breathe, -1.35) * CFrame.Angles(
					0,
					0,
					math.rad(-12 + smoothedRaised * 25)
				)
				else CFrame.new(
					0.65 - swing * direction * 0.85,
					-0.8 + smoothedCharge * 0.18 + breathe,
					-1.15 - swing * 0.35 + recoil * 0.18
				) * CFrame.Angles(
					math.rad(-smoothedCharge * 15 - recoil * 9),
					0,
					math.rad(12 + smoothedCharge * 20 - swing * direction * 85)
				)
			piece.Part.CFrame = current.CFrame * pose * piece.Offset
		end
	end)
end
return View
