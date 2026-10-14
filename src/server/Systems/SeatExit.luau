-- Break the physical seat connection before moving a character to another world.
local SeatExit = {}

function SeatExit.detach(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat then return end
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
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	-- Leave an Outpost mech stationary in the lobby and return physics to the server.
	local machine = seat:GetAttribute("OutpostMachine") and seat.Parent
	local chassis = machine and machine.PrimaryPart
	if chassis then
		local drive = chassis:FindFirstChild("Drive")
		if drive then drive.PlaneVelocity = Vector2.zero end
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
		pcall(chassis.SetNetworkOwner, chassis, nil)
	end
end

return SeatExit
