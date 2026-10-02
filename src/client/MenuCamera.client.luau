--[[
	Menu-only mode (Shared/Config.MenuOnly): the game is played from the
	menu, so the character can't walk around and the camera drifts slowly
	around the moon base station behind the menus (built here, on the
	client). The intro runs its own scenes; this takes over once it's done.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
if not Config.MenuOnly then
	return
end
local MineScene = require(script.Parent.Modules.MineScene)
local Scenes = require(script.Parent.Modules.Scenes)

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

-- The moon base, built once, and a slow orbit around it (the Mine flies
-- off to the mining site; see MineScene).
local BASE_AT = CFrame.new(0, 300, 0)
local base: Scenes.Base? = nil
local started = os.clock()
RunService.RenderStepped:Connect(function()
	-- The intro and the mining site run their own cameras.
	if introOpen() or MineScene.isActive() then
		return
	end
	if not base then
		Scenes.spaceLighting()
		base = Scenes.moonBase(BASE_AT)
	end
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local b = base :: Scenes.Base
	local t = (os.clock() - started) * 0.03 + 0.8
	local eye = b.Center + Vector3.new(math.cos(t) * 120, 42 + math.sin(t * 0.7) * 6, math.sin(t) * 120)
	camera.CFrame = CFrame.lookAt(eye, b.Center)
end)
