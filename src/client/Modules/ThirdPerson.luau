--[[
	Third-person camera for the mining worlds (the Outpost and the mine).

	  ThirdPerson.enter()  starts the camera pulled back behind the player and
	                       keeps it from zooming into first person
	  ThirdPerson.exit()   puts back the camera settings from before
	  ThirdPerson.range()  while it's on: the zoom you have (MinZoom, MaxZoom),
	                       whatever it's holding the camera at for a moment
	  ThirdPerson.home()   while it's on: how far back it starts (StartZoom, or
	                       LobbyZoom on the landing pad)

	Combat's first-person view saves and restores these same settings, so a
	duel at the Outpost hands back to third person when it ends, back out
	where the camera was (FirstPersonCombat).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ThirdPerson = {}
ThirdPerson.StartZoom = 14 -- studs behind the player on arrival
ThirdPerson.LobbyZoom = 18 -- wider view of the mining field on the landing pad
ThirdPerson.MinZoom = 6 -- the closest the player can scroll in
ThirdPerson.MaxZoom = 40

local saved: { Mode: Enum.CameraMode, Min: number, Max: number }? = nil
local RESET_BIND = "SagaArrivalCamera"
local arrival: CFrame? = nil
local homeZoom = ThirdPerson.StartZoom

local function cancelReset()
	RunService:UnbindFromRenderStep(RESET_BIND)
end

function ThirdPerson.enter(destination: CFrame?)
	if not saved then
		saved = { Mode = player.CameraMode, Min = player.CameraMinZoomDistance, Max = player.CameraMaxZoomDistance }
	end
	arrival = destination
	local zoom = if destination then ThirdPerson.LobbyZoom else ThirdPerson.StartZoom
	homeZoom = zoom
	cancelReset()
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = ThirdPerson.MaxZoom
	player.CameraMinZoomDistance = zoom
	-- CombatSession can clear before the teleport reaches the client. Wait
	-- for the destination and two stable frames, after combat camera cleanup.
	local elapsed, stable, applied = 0, 0, false
	local previous: Vector3? = nil
	local previousCharacter: Model? = nil
	RunService:BindToRenderStep(RESET_BIND, Enum.RenderPriority.Camera.Value + 4, function(dt)
		-- (A fight has the camera: an Arena session, or a spar in the lobby
		-- with the kit out. Pulled back to third person under the spar's
		-- first-person view, the mouse stayed locked to the middle.)
		if not saved or player:GetAttribute("CombatSession") ~= nil or player:GetAttribute("Spar") == true then
			-- (Its hold on the zoom goes too, unless the fight's view has the
			-- camera now: kept, it came back after the fight as the closest
			-- you could zoom.)
			if saved and player.CameraMinZoomDistance == zoom then
				player.CameraMinZoomDistance = ThirdPerson.MinZoom
			end
			cancelReset()
			return
		end
		elapsed += dt
		if applied or elapsed > 5 then
			player.CameraMinZoomDistance = ThirdPerson.MinZoom
			cancelReset()
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if not root or not humanoid or humanoid.Health <= 0 or not camera then return end
		if destination and (root.Position - destination.Position).Magnitude > 48 then return end
		if player:GetAttribute("ArenaDropUntil") or player:GetAttribute("ArenaDropPreparing") then return end
		if previousCharacter == character and previous and (root.Position - previous).Magnitude < 4 then
			stable += 1
		else
			stable = 0
		end
		previous, previousCharacter = root.Position, character
		if stable < 2 then return end
		local direction = (destination or root.CFrame).LookVector
		local forward = Vector3.new(direction.X, 0, direction.Z)
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
		local focus = root.Position + Vector3.new(0, 2, 0)
		local eye = focus - forward * zoom + Vector3.new(0, if destination then 8 else 6, 0)
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = ThirdPerson.MaxZoom
		player.CameraMinZoomDistance = zoom
		humanoid.CameraOffset = Vector3.zero
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = CFrame.lookAt(eye, focus)
		camera.Focus = CFrame.new(focus)
		applied = true
	end)
end

function ThirdPerson.range(): (number?, number?)
	if not saved then
		return nil, nil
	end
	return ThirdPerson.MinZoom, ThirdPerson.MaxZoom
end

function ThirdPerson.home(): number?
	return if saved then homeZoom else nil
end

function ThirdPerson.exit()
	cancelReset()
	arrival = nil
	if not saved then
		return
	end
	player.CameraMode = saved.Mode
	player.CameraMinZoomDistance = saved.Min
	player.CameraMaxZoomDistance = saved.Max
	saved = nil
end

player.CharacterAdded:Connect(function()
	if saved and player:GetAttribute("CombatSession") == nil then
		ThirdPerson.enter(arrival)
	end
end)

return ThirdPerson
