-- Server offers the reward; this panel submits only a choice, never a roll or item.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request")
local gui = Instance.new("ScreenGui")
gui.Name = "BossLoot"
gui.ResetOnSpawn = false
gui.DisplayOrder = 130
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(520, 260)
panel.BackgroundColor3 = Color3.fromRGB(18, 24, 39)
panel.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(245, 193, 92)
stroke.Thickness = 2
stroke.Parent = panel
local function label(y, height, size)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(20, y)
	t.Size = UDim2.new(1, -40, 0, height)
	t.TextColor3 = Color3.fromRGB(239, 233, 218)
	t.TextSize = size
	t.Font = Enum.Font.GothamBold
	t.TextWrapped = true
	t.Parent = panel
	return t
end
label(18, 28, 22).Text = "COLOSSUS DEFEATED"
local item = label(54, 42, 18)
label(100, 52, 13).Text =
	"Claim if you want the gem. Multiple claims join the party roll. Roll enters directly; Pass declines. Highest roll wins; ties break randomly."
local status = label(224, 26, 12)
local locked = false
for i, choice in { "Claim", "Roll", "Pass" } do
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(20 + (i - 1) * 164, 166)
	b.Size = UDim2.fromOffset(152, 44)
	b.BackgroundColor3 = Color3.fromRGB(47, 66, 88)
	b.TextColor3 = Color3.fromRGB(255, 220, 134)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 17
	b.Text = string.upper(choice)
	b.Modal = true
	b.Parent = panel
	b.Activated:Connect(function()
		if locked then
			return
		end
		locked = true
		local ok, result = pcall(function()
			return request:InvokeServer("DungeonLootChoice", choice)
		end)
		status.Text = if ok and result then result.Message else "Connection failed. Retry."
		if not ok or not result or not result.Ok then
			locked = false
		end
	end)
end
local function refresh()
	local loot = player:GetAttribute("DungeonLoot")
	gui.Enabled = loot ~= nil
	locked = false
	item.Text = loot or ""
end
player:GetAttributeChangedSignal("DungeonLoot"):Connect(refresh)
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 520, (camera.ViewportSize.Y - 24) / 260)
	end
	if not locked then
		status.Text = string.format(
			"Choose within %ds · No response = Pass",
			math.max(0, math.ceil((player:GetAttribute("DungeonLootDeadline") or 0) - workspace:GetServerTimeNow()))
		)
	end
end)
refresh()
