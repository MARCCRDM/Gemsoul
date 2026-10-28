-- Tells the server which way your camera looks along the ground
-- (Remotes.KaijuView), so your kaiju stand where you can see them: out in
-- front of you as your camera sees it, not behind it off your screen
-- (Shared.Kaiju.leadSpot). Only when it's turned Turn of the way since it
-- last said, and no more often than Every seconds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Every = 0.3
local Turn = math.cos(math.rad(20))

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("KaijuView")

local said: Vector3? = nil
local wait = 0
RunService.Heartbeat:Connect(function(dt)
	wait -= dt
	if wait > 0 then
		return
	end
	wait = Every
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local look = camera.CFrame.LookVector
	local along = Vector3.new(look.X, 0, look.Z)
	if along.Magnitude < 0.2 then
		return -- (looking straight down: it says nothing)
	end
	along = along.Unit
	if said and along:Dot(said) >= Turn then
		return
	end
	said = along
	remote:FireServer(along)
end)
