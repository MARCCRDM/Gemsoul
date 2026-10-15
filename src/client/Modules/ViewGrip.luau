--[[
	How a worn weapon is held in first person (FirstPersonCombat): its frame
	is its grip point, with +Y running up its longest piece (the blade), so
	it can be held at a set angle however it's mounted. A weapon with no
	straight piece off its grip is held along the line from the grip to its
	farthest piece, rather than not at all.

	  ViewGrip.frame(weapon, transparencyOf) -> CFrame?
]]
local ViewGrip = {}

function ViewGrip.frame(weapon: Instance, transparencyOf: (BasePart) -> number): CFrame?
	local grip = weapon:FindFirstChild("RightGrip")
	local blade, length = nil, 0
	for _, part in weapon:GetDescendants() do
		local weld = part:IsA("BasePart") and part:FindFirstChildWhichIsA("WeldConstraint")
		-- Only the right-hand blade defines its frame, never a built-in shield
		-- or the offhand blade of a dual-wield model.
		if
			part:IsA("BasePart")
			and weld
			and weld.Part0 == grip
			and transparencyOf(part) < 1
			and part.Size.Y > length
		then
			if part.Size.Y >= math.max(part.Size.X, part.Size.Z) then
				blade, length = part, part.Size.Y
			end
		end
	end
	if grip and not blade then
		-- No straight piece off the grip: held along the line from the grip
		-- to its farthest piece.
		local far, reach = nil, 0
		for _, part in weapon:GetDescendants() do
			if part:IsA("BasePart") and part ~= grip and transparencyOf(part) < 1 then
				local distance = (part.CFrame.Position - grip.CFrame.Position).Magnitude
				if distance > reach then
					far, reach = part, distance
				end
			end
		end
		if not far or reach < 0.5 then
			return nil
		end
		local up = (far.CFrame.Position - grip.CFrame.Position).Unit
		local right = grip.CFrame.RightVector - up * grip.CFrame.RightVector:Dot(up)
		if right.Magnitude < 0.1 then
			right = grip.CFrame.LookVector - up * grip.CFrame.LookVector:Dot(up)
		end
		return CFrame.fromMatrix(grip.CFrame.Position, right.Unit, up)
	end
	if not grip or not blade then
		return nil
	end
	-- Which way along the blade is the tip (away from the grip).
	local rotation = blade.CFrame.Rotation
	if (blade.CFrame.Position - grip.CFrame.Position):Dot(blade.CFrame.UpVector) < 0 then
		rotation *= CFrame.Angles(0, 0, math.pi)
	end
	return CFrame.new(grip.CFrame.Position) * rotation
end

return ViewGrip
