--[[
	Into a dungeon facing the right way (Server SpawnFacing): once the
	character's there, it's turned to face the way in and the camera swung
	round behind it, looking the same way (a teleport leaves the camera
	looking wherever it was, so forward could be back the way you came).
]]
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local SpawnFacing = {}
SpawnFacing.Behind = 13 -- (studs back from the character)
SpawnFacing.Above = 5
SpawnFacing.Wait = 2 -- (seconds, at most, for the character to get there)

-- The camera behind a character at `at`, looking the way it faces.
function SpawnFacing.cameraFor(at: CFrame): CFrame
	local look = Vector3.new(at.LookVector.X, 0, at.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, 1)
	local eye = at.Position - look * SpawnFacing.Behind + Vector3.new(0, SpawnFacing.Above, 0)
	return CFrame.lookAt(eye, at.Position + look * 8 + Vector3.new(0, 2, 0))
end

local turns = 0
local function turn()
	local spot = player:GetAttribute("SpawnFace")
	if typeof(spot) ~= "CFrame" then
		return
	end
	turns += 1
	local mine = turns
	local started = os.clock()
	-- (The move reaches us a moment after the word of it: wait till it has.)
	while mine == turns and os.clock() - started < SpawnFacing.Wait do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - spot.Position).Magnitude < 12 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + spot.LookVector)
			local camera = workspace.CurrentCamera
			if camera then
				camera.CFrame = SpawnFacing.cameraFor(root.CFrame)
			end
			return
		end
		task.wait()
	end
end

player:GetAttributeChangedSignal("SpawnFaceN"):Connect(function()
	task.spawn(turn)
end)
