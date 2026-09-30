--[[
	Menu-only mode (Shared/Config.MenuOnly): the game is played from the
	menu, so the character can't walk around and the camera drifts slowly
	around the kingdom behind the menus. The intro runs its own flyover;
	this takes over once it's done.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
if not Config.MenuOnly then
	return
end

local player = Players.LocalPlayer

local function introOpen(): boolean
	return player.PlayerGui:FindFirstChild("Intro") ~= nil
end

-- Freeze movement (the controls module can take a moment to load).
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local module = scripts and scripts:WaitForChild("PlayerModule", 10)
	if module then
		local ok, controls = pcall(function()
			return require(module):GetControls()
		end)
		if ok and controls then
			controls:Disable()
		end
	end
end)

-- A slow orbit around the town, a little lower and closer than the intro's.
local started = os.clock()
RunService.RenderStepped:Connect(function()
	if introOpen() then
		return
	end
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local t = (os.clock() - started) * 0.035 + 0.8
	local eye = Vector3.new(math.cos(t) * 135, 55 + math.sin(t * 0.7) * 8, math.sin(t) * 135)
	camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 12, 0))
end)
