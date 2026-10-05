-- The menu dashboard yields its camera and controls during Arena sessions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)
local ArenaScene = {}
local player = Players.LocalPlayer
local active, busy, controls = false, false, nil
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
	controls = require(module):GetControls()
	if active then
		controls:Enable()
	end
end)
local function refresh()
	active = player:GetAttribute("CombatSession") ~= nil
	if Config.MenuOnly then
		local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
		if dashboard then
			dashboard.Enabled = not active and player.PlayerGui:FindFirstChild("Intro") == nil
		end
		if controls then
			if active then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end
	if active then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end
function ArenaScene.enter(pvp)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request(if pvp then "ArenaPvP" else "ArenaTraining")
		busy = false
		-- Walking in says it all; only a refusal needs words.
		if not result.Ok then
			UiKit.toast(result.Message, UiKit.Colors.Bad)
		end
		refresh()
	end)
end
function ArenaScene.leave()
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("ArenaLeave")
		busy = false
		if not result.Ok then
			UiKit.toast(result.Message, UiKit.Colors.Bad)
		end
		refresh()
	end)
end
function ArenaScene.isActive()
	return player:GetAttribute("CombatSession") ~= nil
end
player:GetAttributeChangedSignal("CombatSession"):Connect(refresh)
return ArenaScene
