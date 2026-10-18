-- Let go of a seated character, or a mech's pilot, before moving them to
-- another world.
local SeatExit = {}

local function stand(humanoid: Humanoid, character: Model)
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- The seated body was in someone else's assembly. Let normal character
		-- ownership resume once it's free (including exits before an arena move).
		pcall(root.SetNetworkOwnershipAuto, root)
	end
end

-- A mech's pilot (no seat: Server OutpostVehicles, Shared.MechPilot): the
-- weld that holds them in its cockpit goes, and they're no longer its pilot.
-- Returns whether they were one.
local function unpilot(character: Model): boolean
	local was = false
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local ok, joints = pcall(function()
			return (root :: any):GetJoints()
		end)
		for _, joint in if ok and joints then joints else {} do
			if joint.Name == "PilotWeld" then
				joint:Destroy()
				was = true
			end
		end
	end
	local ok, player = pcall(function()
		return game:GetService("Players"):GetPlayerFromCharacter(character)
	end)
	if ok and player and player:GetAttribute("MechPilot") ~= nil then
		player:SetAttribute("MechPilot", nil)
		was = true
	end
	return was
end

-- `seat` when the caller knows it. Otherwise it's found from the body: the
-- server can see no SeatPart for someone it seated (Shared.Seating).
function SeatExit.detach(character: Model, seat: Instance?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if unpilot(character) and humanoid then
		stand(humanoid, character)
	end
	seat = seat or (humanoid and humanoid.SeatPart)
	if not seat and humanoid then
		local ok, found = pcall(function()
			return require(game:GetService("ReplicatedStorage").Shared.Seating).seatOf(humanoid)
		end)
		seat = if ok then found else nil
	end
	if not seat or not humanoid then return end
	-- Setting Sit alone waits for the humanoid/physics update. The SeatWeld
	-- must be gone synchronously, before PivotTo can drag the whole assembly.
	for _, joint in seat:GetChildren() do
		if joint.Name == "SeatWeld" and joint:IsA("Weld") then
			local a, b = joint.Part0, joint.Part1
			if (a and a:IsDescendantOf(character)) or (b and b:IsDescendantOf(character)) then
				joint:Destroy()
			end
		end
	end
	stand(humanoid, character)
end

return SeatExit
