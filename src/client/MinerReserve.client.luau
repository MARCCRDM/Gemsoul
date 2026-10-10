-- Dungeon replacement selection survives an avatar respawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UiKit = require(script.Parent.Modules.UiKit)
local GemClient = require(script.Parent.Modules.GemClient)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local player = Players.LocalPlayer
local gui = UiKit.gui("MinerReserve", 140)
local function make(kind, props, parent)
	local item = Instance.new(kind)
	for key, value in props do item[key] = value end
	item.Parent = parent
	return item
end
local backdrop = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = UiKit.Colors.Background,
	BackgroundTransparency = 0.18, Visible = false,
}, gui)
local panel = UiKit.panel(backdrop, UiKit.Colors.Gold)
panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(560, 312)
local scale = make("UIScale", {}, panel)
local function label(text, y, height, size, color)
	return make("TextLabel", {
		Text = text, Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, height),
		TextSize = size, TextColor3 = color or UiKit.Colors.Text, Font = Enum.Font.GothamBold,
		BackgroundTransparency = 1, TextWrapped = true,
	}, panel)
end
label("MINER DOWN", 20, 32, 25, UiKit.Colors.Gold)
label("Choose your next miner. Your dungeon continues.", 57, 38, 14)
local timer = label("", 210, 28, 12, UiKit.Colors.Dim)
local pending = false
local buttons = {}
for index = 1, 3 do
	local button = UiKit.button(panel, "MINER " .. index, nil, function()
		if pending then return end
		pending = true
		task.spawn(function()
			local response = GemClient.request("DungeonMinerSelect", index)
			pending = false
			if not response.Ok then UiKit.toast(response.Message) end
		end)
	end)
	button.AutomaticSize = Enum.AutomaticSize.None
	button.Position = UDim2.fromOffset(20 + (index - 1) * 176, 108)
	button.Size = UDim2.fromOffset(168, 88)
	button.TextSize = 15
	button.TextWrapped = true
	buttons[index] = button
end
local leave = UiKit.button(panel, "Leave dungeon", UiKit.Colors.Dim, function()
	task.spawn(function() GemClient.request("ArenaLeave") end)
end)
leave.AnchorPoint, leave.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 253)
local function refresh()
	backdrop.Visible = player:GetAttribute("DungeonSelecting") == true
	local roster = GemClient.Profile and GemClient.Profile.Miners
	local available = "," .. (player:GetAttribute("DungeonAvailableMiners") or "") .. ","
	for index, button in buttons do
		local ready = string.find(available, "," .. index .. ",", 1, true) ~= nil
		local miner = roster and roster.Slots[index]
		local level = Tree.level(miner and miner.Augments and miner.Augments.XP or 0)
		button.Text = string.format("MINER %d · LV %d\n%s", index, level, if ready then "DEPLOY" else "DEFEATED")
		button.Active, button.AutoButtonColor = ready, ready
		button.TextColor3 = if ready then UiKit.Colors.Text else UiKit.Colors.Dim
		button.BackgroundColor3 = if ready then UiKit.Colors.Row else UiKit.Colors.Background
	end
end
for _, key in { "DungeonSelecting", "DungeonAvailableMiners" } do
	player:GetAttributeChangedSignal(key):Connect(refresh)
end
GemClient.Changed:Connect(refresh)
RunService.RenderStepped:Connect(function()
	if not backdrop.Visible then return end
	scale.Scale = math.min(1, (backdrop.AbsoluteSize.X - 24) / 560, (backdrop.AbsoluteSize.Y - 24) / 312)
	local seconds = math.max(0, math.ceil((player:GetAttribute("DungeonSelectEnds") or 0) - workspace:GetServerTimeNow()))
	timer.Text = if pending then "Deploying…" else string.format("Auto-deploy in %ds · Each miner gets one life per run", seconds)
end)
refresh()
