-- Tells the server each time you jump (Remotes.KaijuJump), so your kaiju
-- jump after you every time, however fast you jump again (KaijuServer's
-- hops: it also watches you rise, and counts a jump seen both ways once).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("KaijuJump")

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	humanoid.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Jumping then
			remote:FireServer()
		end
	end)
end

if player.Character then
	task.spawn(watch, player.Character)
end
player.CharacterAdded:Connect(watch)
