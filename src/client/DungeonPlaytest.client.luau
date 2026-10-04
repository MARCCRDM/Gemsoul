-- Owner-only test controls. Authorization is independently checked on every server request.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local request = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Request")
local player = Players.LocalPlayer
-- Permissions can arrive after this script starts; never infer authorization locally.
while player:GetAttribute("CanTestDungeon") == nil do
	player:GetAttributeChangedSignal("CanTestDungeon"):Wait()
end
if player:GetAttribute("CanTestDungeon") ~= true then
	return
end
local gui = Instance.new("ScreenGui")
gui.Name = "DungeonPlaytest"
gui.ResetOnSpawn = false
gui.DisplayOrder = 120
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 118)
panel.Position = UDim2.new(0, 16, 1, -140)
panel.BackgroundColor3 = Color3.fromRGB(17, 25, 36)
panel.Parent = gui
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 40)
status.Position = UDim2.fromOffset(6, 4)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 210, 126)
status.TextWrapped = true
status.TextSize = 13
status.Font = Enum.Font.GothamBold
status.Text = "OWNER DUNGEON TEST / NO REWARDS"
status.Parent = panel
local busy = false
local function run(mode)
	if busy then
		return
	end
	busy = true
	status.Text = "Loading..."
	local ok, result = pcall(function()
		if mode == "Exit" then
			return request:InvokeServer("ArenaLeave")
		end
		return request:InvokeServer("DungeonTest", mode)
	end)
	status.Text = if ok and result then result.Message else "Request failed. Finish the intro, then retry."
	busy = false
end
for i, item in { { "F7 / DUNGEON", "Full" }, { "F8 / TUNG TUNG", "Sahur" }, { "EXIT TEST", "Exit" } } do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(if i == 3 then 288 else 141, 28)
	b.Position = UDim2.fromOffset(if i == 2 then 153 else 6, if i == 3 then 82 else 48)
	b.BackgroundColor3 = Color3.fromRGB(39, 61, 79)
	b.TextColor3 = Color3.fromRGB(240, 245, 250)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = item[1]
	b.Parent = panel
	b.Activated:Connect(function()
		run(item[2])
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.F7 then
		run("Full")
	elseif input.KeyCode == Enum.KeyCode.F8 then
		run("Sahur")
	end
end)
