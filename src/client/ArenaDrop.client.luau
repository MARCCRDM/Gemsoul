-- Helmet POV throughout insertion. Camera follows the local pod, never an exterior shot.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local savedCamera, savedType, savedSubject, savedFov
local hidden = {}
local hudSaved = {}
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ArenaInsertion", false, 40
local label = Instance.new("TextLabel")
label.AnchorPoint, label.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -26)
label.Size = UDim2.new(0.8, 0, 0, 56)
label.BackgroundColor3, label.BackgroundTransparency = Color3.fromRGB(7, 12, 20), 0.2
label.TextColor3, label.Font, label.TextSize = Color3.fromRGB(110, 230, 255), Enum.Font.GothamBold, 18
label.TextWrapped = true
label.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 160, 190)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = label
local function restore()
	if savedCamera then
		savedCamera.CameraType = savedType
		savedCamera.FieldOfView = savedFov
		savedCamera.CameraSubject = if savedSubject and savedSubject.Parent
			then savedSubject
			else (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
		savedCamera = nil
	end
	for object, value in hidden do
		if object.Parent then
			object.LocalTransparencyModifier = value
		end
	end
	table.clear(hidden)
	for hud, enabled in hudSaved do
		if hud.Parent then
			hud.Enabled = enabled
		end
	end
	table.clear(hudSaved)
	gui.Enabled = false
end
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
RunService:BindToRenderStep("ArenaInsertionCamera", Enum.RenderPriority.Camera.Value + 2, function()
	local ends, focus = player:GetAttribute("ArenaDropUntil"), player:GetAttribute("ArenaDropFocus")
	local camera = workspace.CurrentCamera
	if type(ends) ~= "number" or ends <= workspace:GetServerTimeNow() or typeof(focus) ~= "Vector3" or not camera then
		restore()
		return
	end
	if not savedCamera then
		savedCamera, savedType, savedSubject, savedFov =
			camera, camera.CameraType, camera.CameraSubject, camera.FieldOfView
	end
	for _, name in { "CombatHud", "LobbyHud", "Toasts" } do
		local hud = player.PlayerGui:FindFirstChild(name)
		if hud and hud:IsA("ScreenGui") then
			if hudSaved[hud] == nil then
				hudSaved[hud] = hud.Enabled
			end
			hud.Enabled = false
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then
		restore()
		return
	end
	local now = workspace:GetServerTimeNow()
	local start = character:GetAttribute("ArenaDropStart")
	local elapsed = if type(start) == "number" then now - start else 10
	local descent = math.clamp(elapsed / 0.72, 0, 1)
	local height = if elapsed < 0.72 then 100 * (1 - descent * descent) else 0
	local impactAge = elapsed - 0.72
	local kick = if impactAge >= 0 then math.exp(-impactAge * 9) else 0
	local pitch = math.sin(math.max(impactAge, 0) * 32) * 0.035 * kick
	local eye = root.Position + Vector3.new(0, head.Position.Y - root.Position.Y + height - kick * 0.22, 0)
	camera.CFrame = CFrame.lookAt(eye, eye + root.CFrame.LookVector) * CFrame.Angles(pitch, 0, pitch * 0.3)
	camera.FieldOfView = savedFov
		+ (if elapsed >= 0 and elapsed < 0.72 then math.sin(descent * math.pi) * 5 else kick * 2)
	if character then
		for _, object in character:GetDescendants() do
			if object:IsA("BasePart") then
				if hidden[object] == nil then
					hidden[object] = object.LocalTransparencyModifier
				end
				object.LocalTransparencyModifier = 1
			end
		end
	end
	local view = camera:FindFirstChild("FirstPersonLoadout")
	if view then
		for _, object in view:GetDescendants() do
			if object:IsA("BasePart") then
				if hidden[object] == nil then
					hidden[object] = object.LocalTransparencyModifier
				end
				object.LocalTransparencyModifier = if elapsed < 1.45 then 1 else 0
			end
		end
	end
	gui.Enabled = true
	local remaining = ends - workspace:GetServerTimeNow()
	label.Text = if remaining > 1.8
		then (if elapsed < 0
			then "DROP QUEUED  /  BRACE"
			elseif elapsed < 0.72 then "ORBITAL DESCENT  /  BRACE"
			elseif elapsed < 1.1 then "IMPACT  /  RELEASING HATCH"
			else "VISUAL CONTACT  /  STAND BY")
		else "WEAPONS LIVE IN " .. math.ceil(remaining)
end)
