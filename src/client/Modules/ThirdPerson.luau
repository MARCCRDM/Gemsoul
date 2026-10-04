--[[
	Third-person camera for the mining worlds (the Outpost and the mine).

	  ThirdPerson.enter()  starts the camera pulled back behind the player and
	                       keeps it from zooming into first person
	  ThirdPerson.exit()   puts back the camera settings from before

	Combat's first-person view saves and restores these same settings, so a
	duel at the Outpost hands back to third person when it ends.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ThirdPerson = {}
ThirdPerson.StartZoom = 14 -- studs behind the player on arrival
ThirdPerson.MinZoom = 6 -- the closest the player can scroll in
ThirdPerson.MaxZoom = 40

local saved: { Mode: Enum.CameraMode, Min: number, Max: number }? = nil

function ThirdPerson.enter()
	if not saved then
		saved = { Mode = player.CameraMode, Min = player.CameraMinZoomDistance, Max = player.CameraMaxZoomDistance }
	end
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = ThirdPerson.MaxZoom
	-- Raising the minimum pushes the camera out to it; after a frame, let the
	-- player scroll in again, but never into first person.
	player.CameraMinZoomDistance = ThirdPerson.StartZoom
	task.defer(function()
		RunService.RenderStepped:Wait()
		if saved then
			player.CameraMinZoomDistance = ThirdPerson.MinZoom
		end
	end)
end

function ThirdPerson.exit()
	if not saved then
		return
	end
	player.CameraMode = saved.Mode
	player.CameraMinZoomDistance = saved.Min
	player.CameraMaxZoomDistance = saved.Max
	saved = nil
end

return ThirdPerson
