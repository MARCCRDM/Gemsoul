-- Compact dungeon objective strip, using the same first-person session lifecycle.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "DungeonStatus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 22
gui.Parent = player:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 54)
frame.Size = UDim2.new(0.72, 0, 0, 66)
frame.BackgroundColor3 = Color3.fromRGB(14, 24, 34)
frame.BackgroundTransparency = 0.12
frame.BorderSizePixel = 0
frame.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(640, 80)
limit.Parent = frame
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(238, 177, 83)
stroke.Transparency = 0.3
stroke.Parent = frame
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 22)
title.Position = UDim2.fromOffset(10, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(255, 205, 128)
title.Parent = frame
local objective = Instance.new("TextLabel")
objective.Size = UDim2.new(1, -20, 0, 34)
objective.Position = UDim2.fromOffset(10, 27)
objective.BackgroundTransparency = 1
objective.TextWrapped = true
objective.Font = Enum.Font.Gotham
objective.TextSize = 13
objective.TextColor3 = Color3.fromRGB(225, 237, 246)
objective.Parent = frame
local function refresh()
	gui.Enabled = player:GetAttribute("DungeonId") ~= nil
	title.Text = if player:GetAttribute("DungeonTest")
		then "OWNER DUNGEON TEST / NO REWARDS"
		else string.format("SQUAD DUNGEON  •  ROOM %d / 5", player:GetAttribute("DungeonRoom") or 1)
	objective.Text = player:GetAttribute("DungeonObjective") or "Your squad is deploying…"
end
for _, attribute in { "DungeonId", "DungeonRoom", "DungeonObjective" } do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()
