-- Shared arena establishing shot; participants see both insertions from the same side.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local savedCamera, savedType, savedSubject
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
RunService:BindToRenderStep("ArenaInsertionCamera", Enum.RenderPriority.Last.Value + 10, function()
	local ends, focus = player:GetAttribute("ArenaDropUntil"), player:GetAttribute("ArenaDropFocus")
	local camera = workspace.CurrentCamera
	if type(ends) ~= "number" or ends <= workspace:GetServerTimeNow() or typeof(focus) ~= "Vector3" or not camera then
		restore()
		return
	end
	if not savedCamera then
		savedCamera, savedType, savedSubject = camera, camera.CameraType, camera.CameraSubject
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
	-- A broad side angle keeps both entry points visible; no impact shake or aim movement.
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local distance = if aspect < 1.3 then 72 else 52
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.8, 18, distance * 0.7), focus + Vector3.new(0, 3, 0))
	local character = player.Character
	if character then
		for _, object in character:GetDescendants() do
			if object:IsA("BasePart") then
				if hidden[object] == nil then
					hidden[object] = object.LocalTransparencyModifier
				end
				object.LocalTransparencyModifier = 0
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
				object.LocalTransparencyModifier = 1
			end
		end
	end
	gui.Enabled = true
	local remaining = ends - workspace:GetServerTimeNow()
	label.Text = if remaining > 1.8
		then "ORBITAL INSERTION  /  STAND BY"
		else "WEAPONS LIVE IN " .. math.ceil(remaining)
end)
