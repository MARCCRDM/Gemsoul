-- First-person insertion: deterministic local presentation, authoritative server staging.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Shared.InsertionMotion)
local Pod = require(script.Parent.Modules.InsertionPod)
local player = Players.LocalPlayer
local pods, hidden, hudSaved = {}, {}, {}
local savedCamera, savedType, savedSubject, savedFov, generation, entered, eyeHeight
local characterConnection
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "ArenaInsertion", false, 40, true
local veil = Instance.new("Frame")
veil.Size, veil.BackgroundColor3, veil.BorderSizePixel = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 0
veil.ZIndex, veil.Parent = 2, gui
local label = Instance.new("TextLabel")
label.AnchorPoint, label.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -34)
label.Size, label.BackgroundTransparency = UDim2.new(0.78, 0, 0, 28), 1
label.TextColor3, label.Font, label.TextSize = Color3.fromRGB(155, 226, 235), Enum.Font.GothamMedium, 14
label.TextWrapped, label.ZIndex, label.Parent = true, 3, gui
local function hideBody(object)
	if object:IsA("BasePart") then
		if hidden[object] == nil then
			hidden[object] = object.LocalTransparencyModifier
		end
		object.LocalTransparencyModifier = 1
	elseif object:IsA("Highlight") and object.Name == "InsertionSilhouette" then
		object.Enabled = false
	end
end
local function restore()
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if savedCamera then
		savedCamera.CameraType = savedType
		savedCamera.FieldOfView = savedFov
		savedCamera.CameraSubject = if savedSubject and savedSubject.Parent
			then savedSubject
			else (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
	end
	savedCamera, generation = nil, nil
	for object, value in hidden do
		if object.Parent then
			object.LocalTransparencyModifier = value
		end
	end
	table.clear(hidden)
	for hud, enabled in hudSaved do
		if hud.Parent and hud.Name ~= "LobbyHud" then
			hud.Enabled = enabled
		end
	end
	table.clear(hudSaved)
	-- The lobby bar isn't put back as it was when the drop began: a duel from
	-- the Outpost starts with it still up, and restoring that left PLAY and the
	-- lobby tiles over the fight's HUD. The lobby decides (LobbyUI).
	require(script.Parent.Modules.LobbyUI).refresh()
	gui.Enabled = false
end
local function discover(object)
	if object.Name == "OrbitalInsertion" and object:IsA("Folder") and not pods[object] then
		pods[object] = Pod.new(object)
	end
end
workspace.ChildAdded:Connect(discover)
for _, object in workspace:GetChildren() do
	discover(object)
end
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
-- Let Roblox's camera produce the destination POV during the final half-second.
-- The later callback eases toward it, avoiding a one-frame snap back to gameplay.
RunService:BindToRenderStep("InsertionCameraHandoff", Enum.RenderPriority.Camera.Value - 1, function()
	local ends = player:GetAttribute("ArenaDropUntil")
	if savedCamera and type(ends) == "number" and ends - workspace:GetServerTimeNow() < 0.5 then
		savedCamera.CameraType = Enum.CameraType.Custom
	end
end)
RunService:BindToRenderStep("ArenaInsertionCamera", Enum.RenderPriority.Camera.Value + 2, function()
	local now = workspace:GetServerTimeNow()
	for marker, pod in pods do
		if not marker.Parent then
			pod.destroy()
			pods[marker] = nil
		else
			pod.update(now)
		end
	end
	local preparation = player:GetAttribute("ArenaDropPreparing")
	local requested = player:GetAttribute("LocalInsertionPending")
	local ends = player:GetAttribute("ArenaDropUntil")
	if
		(type(preparation) == "number" and preparation > now)
		or (type(requested) == "number" and requested > now and type(ends) ~= "number")
	then
		gui.Enabled = true
		veil.BackgroundTransparency = 0
		label.Text, label.TextTransparency = "INSERTION LINK  /  SECURING HARNESS", 0
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		type(ends) ~= "number"
		or ends <= now
		or not camera
		or not root
		or not head
		or not humanoid
		or humanoid.Health <= 0
	then
		restore()
		return
	end
	if savedCamera and (savedCamera ~= camera or savedSubject ~= humanoid) then
		restore()
	end
	if not savedCamera then
		savedCamera, savedType, savedSubject, savedFov = camera, camera.CameraType, humanoid, camera.FieldOfView
		generation, entered, eyeHeight = ends, now, math.clamp(head.Position.Y - root.Position.Y, 1.2, 2.5)
		for _, object in character:GetDescendants() do
			hideBody(object)
		end
		characterConnection = character.DescendantAdded:Connect(hideBody)
	elseif generation ~= ends then
		generation, entered = ends, now
	end
	local start = character:GetAttribute("ArenaDropStart")
	local origin = character:GetAttribute("ArenaDropOrigin")
	-- Attributes may arrive in different packets: never invent a time or height.
	if typeof(origin) ~= "CFrame" then
		gui.Enabled = true
		veil.BackgroundTransparency = 0
		label.Text = "INSERTION LINK"
		return
	end
	local t = if type(start) == "number" then now - start else Motion.Ready + 1
	if type(start) == "number" then
		local ready = false
		for marker, pod in pods do
			local actor = marker:FindFirstChild("Actor")
			if actor and actor.Value == character and pod.Ready and marker:GetAttribute("Start") == start then
				ready = true
				break
			end
		end
		if not ready then
			entered = now
			gui.Enabled = true
			veil.BackgroundTransparency = 0
			label.Text = "INSERTION LINK  /  PRESSURIZING"
			return
		end
	end
	player:SetAttribute("LocalInsertionPending", nil)
	local releaseDelay = character:GetAttribute("ArenaDropReleaseDelay") or 0
	local pose = Motion.sample(t, releaseDelay)
	local ownDrop = type(start) == "number"
	local eye = origin
		* CFrame.new(0, eyeHeight + (if ownDrop then pose.Height - pose.Impact * 0.2 + pose.Bob else 0), -pose.Step)
	if not ownDrop then
		eye = root.CFrame * CFrame.new(0, eyeHeight, 0)
	end
	local animation = eye * CFrame.Angles(pose.Pitch, 0, pose.Impact * 0.009)
	local remaining = ends - now
	if remaining < 0.5 then
		local blend = Motion.smooth(1 - remaining / 0.5)
		animation = animation:Lerp(camera.CFrame, blend)
	else
		camera.CameraType = Enum.CameraType.Scriptable
	end
	camera.CFrame = animation
	camera.FieldOfView = savedFov + pose.Fov
	for _, name in { "CombatHud", "LobbyHud", "Toasts" } do
		local hud = player.PlayerGui:FindFirstChild(name)
		if hud and hud:IsA("ScreenGui") then
			if hudSaved[hud] == nil then
				hudSaved[hud] = hud.Enabled
			end
			hud.Enabled = false
		end
	end
	for object in hidden do
		if object.Parent then
			object.LocalTransparencyModifier = 1
		else
			hidden[object] = nil
		end
	end
	gui.Enabled = true
	-- Helmet wakes inside the already-present pod; the height change is covered.
	veil.BackgroundTransparency = Motion.smooth((now - entered) / 0.32)
	label.Text = if remaining < 1
		then "SAFETIES RELEASING"
		elseif not ownDrop or t >= Motion.Ready + releaseDelay then "RIVAL INBOUND  /  HOLD POSITION"
		elseif t < 0 then "HARNESS LOCKED"
		elseif t < Motion.Landing then "DESCENT  /  BRACE"
		elseif t < Motion.Hatch then "CONTACT  /  PRESSURE RELEASE"
		elseif t < Motion.Exit + releaseDelay then "HATCH CLEAR"
		else "WEAPONS READY"
	label.TextTransparency = if remaining < 0.35 then 1 - remaining / 0.35 else 0.08
end)
