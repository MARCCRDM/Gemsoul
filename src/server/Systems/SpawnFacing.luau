--[[
	Into a dungeon facing the right way: the character placed facing the way
	in, and (Client SpawnFacing) its camera swung round behind it to look the
	same way. A teleport moves the character but leaves the camera where it
	was looking, so "forward" could be straight back at the way you came.

	  SpawnFacing.place(player, cframe)   puts them there, facing its look
	  SpawnFacing.toward(at, target)      a CFrame at `at` facing `target`
	                                      (level: no tilt)

	The client hears of it by two attributes: SpawnFace (the CFrame) and
	SpawnFaceN (counts up, so the same spot twice still turns them).
]]
local SpawnFacing = {}

-- A CFrame at `at` facing `target` on the level (or +Z if they're one spot).
function SpawnFacing.toward(at: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(at, at + flat.Unit)
end

function SpawnFacing.place(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	-- (Level: a spot looked at from above or below never tips them over.)
	local look = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
	local level = if look.Magnitude > 0.01 then CFrame.lookAt(cframe.Position, cframe.Position + look.Unit) else CFrame.new(cframe.Position)
	character:PivotTo(level)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	player:SetAttribute("SpawnFace", level)
	player:SetAttribute("SpawnFaceN", (player:GetAttribute("SpawnFaceN") or 0) + 1)
end

return SpawnFacing
