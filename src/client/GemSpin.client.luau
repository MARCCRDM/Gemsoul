-- Spins and bobs the gems on each player's screen (visual only).
local RunService = game:GetService("RunService")

local gemFolder = workspace:WaitForChild("Gems")
local baseY = {}

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, gem in gemFolder:GetChildren() do
		if gem:IsA("BasePart") then
			baseY[gem] = baseY[gem] or gem.Position.Y
			local pos = gem.Position
			gem.CFrame = CFrame.new(pos.X, baseY[gem] + math.sin(t * 2) * 0.5, pos.Z)
				* CFrame.Angles(0, t * 2, 0)
		end
	end
end)
