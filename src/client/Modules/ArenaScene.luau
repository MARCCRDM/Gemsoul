-- The menu dashboard yields its camera and controls during Arena sessions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)
local ArenaScene = {}
local player = Players.LocalPlayer
local active, busy, controls = false, false, nil
local function worldActive(): boolean
	return player:GetAttribute("Outpost") == true or player:GetAttribute("Expedition") ~= nil
end
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
	controls = require(module):GetControls()
	if player:GetAttribute("CombatSession") ~= nil or worldActive() then
		controls:Enable()
	end
end)
local function refresh()
	active = player:GetAttribute("CombatSession") ~= nil
	if Config.MenuOnly then
		local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
		if dashboard and (active or not worldActive()) then
			dashboard.Enabled = not active and player.PlayerGui:FindFirstChild("Intro") == nil
		end
		if controls then
			if active or worldActive() then
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
	player:SetAttribute("LocalInsertionPending",workspace:GetServerTimeNow()+15)
	task.spawn(function()
		local result = GemClient.request(if pvp then "ArenaPvP" else "ArenaTraining")
		busy = false
		-- Walking in says it all; only a refusal needs words.
		if not result.Ok then
			player:SetAttribute("LocalInsertionPending",nil)
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
player:GetAttributeChangedSignal("Outpost"):Connect(refresh)
player:GetAttributeChangedSignal("Expedition"):Connect(refresh)
return ArenaScene
