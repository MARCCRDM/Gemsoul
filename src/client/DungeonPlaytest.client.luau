-- Owner-only test controls, folded into a small DEV button in the bottom-right
-- corner: dungeon tests (F7 / F8 work any time), leaving a test, and the
-- loadout and gem rerolls. Authorization is independently checked on every
-- server request.
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

local function corner(object: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
end

-- The DEV button, in the strip the dashboard keeps clear along the bottom.
local toggle = Instance.new("TextButton")
toggle.AnchorPoint = Vector2.new(1, 1)
toggle.Position = UDim2.new(1, -14, 1, -8)
toggle.Size = UDim2.fromOffset(74, 28)
toggle.BackgroundColor3 = Color3.fromRGB(39, 61, 79)
toggle.TextColor3 = Color3.fromRGB(255, 210, 126)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.Text = "DEV  ▴"
toggle.Parent = gui
corner(toggle, 6)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -14, 1, -42)
panel.Size = UDim2.fromOffset(300, 262)
panel.BackgroundColor3 = Color3.fromRGB(17, 25, 36)
panel.Visible = false
panel.Parent = gui
corner(panel, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 126)
stroke.Transparency = 0.6
stroke.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 36)
status.Position = UDim2.fromOffset(6, 4)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 210, 126)
status.TextWrapped = true
status.TextSize = 12
status.Font = Enum.Font.GothamBold
status.Text = "OWNER TOOLS · DUNGEON TESTS GIVE NO REWARDS"
status.Parent = panel

-- Touch screens: the bottom-right corner is the thumb's (Combat's buttons),
-- so the DEV button moves up under LEAVE and its panel opens downward.
if game:GetService("UserInputService").TouchEnabled then
	toggle.AnchorPoint, toggle.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 62)
	panel.AnchorPoint, panel.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 96)
	toggle.Text = "DEV  ▾"
end
local function arrow(open: boolean): string
	local touch = game:GetService("UserInputService").TouchEnabled
	return if open == touch then "DEV  ▴" else "DEV  ▾"
end

toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
	toggle.Text = arrow(panel.Visible)
end)

local busy = false
local function run(action: string, ...)
	if busy then
		return
	end
	busy = true
	status.Text = "Loading..."
	local args = table.pack(...)
	local ok, result = pcall(function()
		return request:InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	status.Text = if ok and result then result.Message else "Request failed. Finish the intro, then retry."
	busy = false
end

local buttons = {
	{ "F7 / PATHWAY", "DungeonTest", "Full" },
	{ "F8 / TUNG TUNG", "DungeonTest", "Sahur" },
	{ "OPEN WORLD DUNGEON TEST", "DungeonTest", "OpenWorld" },
	{ "EXIT TEST", "ArenaLeave" },
	{ "REGENERATE LOADOUT", "AdminRegenerateEquipment" },
	{ "REROLL 3 GEMS", "AdminRegenerateGems" },
}
for i, item in buttons do
	local b = Instance.new("TextButton")
	local wide = i >= 3
	b.Size = UDim2.fromOffset(if wide then 288 else 141, 26)
	b.Position = UDim2.fromOffset(if i == 2 then 153 else 6, if i <= 2 then 44 else 44 + (i - 2) * 32)
	b.BackgroundColor3 = if i >= 5 then Color3.fromRGB(70, 46, 84) else Color3.fromRGB(39, 61, 79)
	b.TextColor3 = Color3.fromRGB(240, 245, 250)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = item[1]
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		if item[3] then
			run(item[2], item[3])
		else
			run(item[2])
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.F7 then
		run("DungeonTest", "Full")
	elseif input.KeyCode == Enum.KeyCode.F8 then
		run("DungeonTest", "Sahur")
	end
end)

-- POSE CHECK: how the nearest other fighter's body is being posed on this
-- screen (Shared.RivalPose), to tell why a foe might not visibly swing or
-- guard: joints found (Motor6Ds), frames posed, resets (something else put a
-- bent joint back), the largest bend now and the action it's showing.
local RivalPose = require(game:GetService("ReplicatedStorage").Shared.RivalPose)
local poseLine = Instance.new("TextLabel")
poseLine.Size = UDim2.new(1, -12, 0, 46)
poseLine.Position = UDim2.fromOffset(6, 210)
poseLine.BackgroundTransparency = 1
poseLine.TextColor3 = Color3.fromRGB(160, 230, 255)
poseLine.TextWrapped = true
poseLine.TextXAlignment = Enum.TextXAlignment.Left
poseLine.TextSize = 11
poseLine.Font = Enum.Font.GothamMedium
poseLine.Text = "POSE CHECK: open near a fighter"
poseLine.Parent = panel

local function nearestFighter(): Model?
	local own = player.Character
	local eye = own and own:FindFirstChild("HumanoidRootPart")
	if not eye then
		return nil
	end
	local best, bestDistance = nil, 220
	local function consider(model)
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if model and model ~= own and root and root:IsA("BasePart") then
			local distance = (root.Position - eye.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	for _, other in Players:GetPlayers() do
		consider(other.Character)
	end
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		consider(model)
	end
	return best
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.Visible then
			local model = nearestFighter()
			local info = model and RivalPose.inspect(model)
			poseLine.Text = if not model
				then "POSE CHECK: no fighter nearby"
				elseif not info then string.format(
					"POSE CHECK %s: NOT POSED (BodyPoses never reached it)",
					model.Name
				)
				else string.format(
					"POSE CHECK %s: joints %d (%d motor) · frames %d · resets %d · bend %.2f · %s",
					model.Name,
					info.Found,
					info.Motors,
					info.Updates,
					info.Resets,
					info.Bend,
					info.Action or "idle"
				)
		end
	end
end)
