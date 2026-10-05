--[[
	Landscape only. Runs from ReplicatedFirst, before anything else loads, so
	phones and tablets turn sideways the moment the game opens (like other
	landscape games). LandscapeSensor: either way up, never portrait. If
	anything changes it, it's put straight back.
]]
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LANDSCAPE = Enum.ScreenOrientation.LandscapeSensor

pcall(function()
	StarterGui.ScreenOrientation = LANDSCAPE
end)

local player = Players.LocalPlayer
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")

local function lock()
	if playerGui.ScreenOrientation ~= LANDSCAPE then
		playerGui.ScreenOrientation = LANDSCAPE
	end
end
lock()
playerGui:GetPropertyChangedSignal("ScreenOrientation"):Connect(lock)
