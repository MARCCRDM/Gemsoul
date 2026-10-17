-- Break the physical seat connection before moving a character to another world.
local SeatExit = {}

-- `seat` when the caller knows it. Otherwise it's found from the body: the
-- server can see no SeatPart for someone it seated (Shared.Seating).
function SeatExit.detach(character: Model, seat: Instance?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
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
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- The seated assembly was server-owned. Let normal character ownership
		-- resume once the weld is broken (including exits before an arena move).
		pcall(root.SetNetworkOwnershipAuto, root)
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
