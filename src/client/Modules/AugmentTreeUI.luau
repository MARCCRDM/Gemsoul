-- Connected node graph; three columns on desktop, branch tabs on narrow screens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Combat = require(ReplicatedStorage.Shared.Combat)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local UI = {}
local player = Players.LocalPlayer
local P = IronUi.Colors
local new, text = IronUi.new, IronUi.text
local gui = UiKit.gui("AugmentTree", 12)
gui.Enabled = false
local shade = new("TextButton", {
	Text = "",
	Modal = true,
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.3,
	Size = UDim2.fromScale(1, 1),
}, gui)
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -24, 1, -32),
	BackgroundColor3 = P.Inset,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(1120, 780) }, panel)
UiKit.round(panel, 14)
local title = text(panel, "AUGMENT TREE", 21, P.Gold, IronUi.Heading)
title.Position, title.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -76, 0, 28)
local close = new("TextButton", {
	Text = "×",
	TextColor3 = P.Text,
	TextSize = 26,
	BackgroundTransparency = 1,
	Position = UDim2.new(1, -48, 0, 8),
	Size = UDim2.fromOffset(36, 36),
}, panel)
local points = text(panel, "", 13, P.Teal, IronUi.Bold)
points.Position, points.Size = UDim2.fromOffset(16, 46), UDim2.new(1, -32, 0, 20)
local progress = text(panel, "", 11, P.Dim)
progress.Position, progress.Size = UDim2.fromOffset(16, 69), UDim2.new(1, -32, 0, 18)
local colors =
	{ RigManeuvers = Color3.fromRGB(65, 195, 112), GemSurges = Color3.fromRGB(70, 130, 255), PassiveAugments = P.Gold }
local tabs, branch = {}, "RigManeuvers"
for index, id in Tree.Branches do
	local button = new("TextButton", {
		Text = Tree.BranchNames[id],
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = colors[id],
		BackgroundColor3 = Color3.fromRGB(32, 29, 46),
		Size = UDim2.new(1 / 3, -14, 0, 36),
		Position = UDim2.new((index - 1) / 3, 12, 0, 92),
	}, panel)
	UiKit.round(button, 7)
	tabs[id] = button
	button.Activated:Connect(function()
		UI.selectBranch(id)
	end)
end
local canvas = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	Position = UDim2.fromOffset(12, 136),
	Size = UDim2.new(1, -24, 1, -294),
	CanvasSize = UDim2.fromOffset(0, 500),
}, panel)
local detail = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(26, 23, 39),
	Position = UDim2.new(0, 12, 1, -150),
	Size = UDim2.new(1, -24, 0, 138),
}, panel)
UiKit.round(detail, 10)
local detailTitle = text(detail, "Select a node", 14, P.Gold, IronUi.Bold)
detailTitle.Position, detailTitle.Size = UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 20)
local description = text(detail, "", 12, P.Text)
description.Position, description.Size, description.TextWrapped =
	UDim2.fromOffset(10, 32), UDim2.new(1, -20, 0, 38), true
local prerequisite = text(detail, "", 11, P.Dim)
prerequisite.Position, prerequisite.Size = UDim2.fromOffset(10, 73), UDim2.new(1, -20, 0, 18)
local unlock = new("TextButton", {
	Text = "UNLOCK",
	TextColor3 = P.Text,
	TextSize = 12,
	BackgroundColor3 = colors.RigManeuvers,
	Position = UDim2.fromOffset(10, 99),
	Size = UDim2.new(0.56, -15, 0, 30),
}, detail)
UiKit.round(unlock, 7)
local reset = new("TextButton", {
	Text = "RESET & REFUND",
	TextColor3 = P.Gold,
	TextSize = 11,
	BackgroundColor3 = P.Inset,
	Position = UDim2.new(0.56, 0, 0, 99),
	Size = UDim2.new(0.44, -10, 0, 30),
}, detail)
UiKit.round(reset, 7)
local selected, busy = "HydraulicSlam", false
local buttons = {}
local function canChange()
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight(root.Position)
end
local function updateDetail()
	local profile, node = GemClient.Profile, Tree.Nodes[selected]
	if not profile or not node then
		return
	end
	local data = Tree.initialize(profile)
	local learned = data.Unlocked[selected] == true
	local parentMet = not node.Parent or data.Unlocked[node.Parent] == true
	detailTitle.Text = node.Icon .. " " .. node.Name
	description.Text = node.Description
	prerequisite.Text = if not canChange()
		then "Return to the dashboard or town to change augments."
		elseif node.Parent then "Requires: " .. Tree.Nodes[node.Parent].Name
		else "Starting node · no prerequisite"
	unlock.Text = if busy
		then "APPLYING…"
		elseif learned then "UNLOCKED"
		elseif not parentMet then "PREREQUISITE LOCKED"
		elseif data.Points < node.Cost then "NEED MORE POINTS"
		else string.format("UNLOCK · %d POINT%s", node.Cost, if node.Cost == 1 then "" else "S")
	unlock.BackgroundColor3 = if learned
			or not parentMet
			or data.Points < node.Cost
			or not canChange()
		then Color3.fromRGB(58, 54, 69)
		else colors[node.Branch]
	unlock.Active = not busy and not learned and parentMet and data.Points >= node.Cost and canChange()
	reset.Active = not busy and canChange() and data.Spent > 0
	reset.TextColor3 = if reset.Active then P.Gold else P.Dim
	for id, button in buttons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = if id == selected then 3 else 1
		end
	end
end
local function line(parent, from, to, color)
	local delta = to - from
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2),
		Size = UDim2.fromOffset(delta.Magnitude, 3),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		ZIndex = 1,
	}, parent)
end
function UI.selectBranch(id)
	if not Tree.Order[id] then
		return
	end
	branch = id
	if Tree.Nodes[selected].Branch ~= id then
		selected = Tree.Order[id][1]
	end
	UI.refresh()
end
function UI.refresh()
	if not gui.Enabled or not GemClient.Profile then
		return
	end
	local data = Tree.initialize(GemClient.Profile)
	points.Text = string.format("%d AUGMENT POINTS AVAILABLE · %d SPENT", data.Points, data.Spent)
	progress.Text = if data.Earned >= Tree.MaxPoints
		then "All Augment Points earned · reset freely outside combat"
		else string.format(
			"%d / %d XP · mine, sell or fight for more",
			data.XP % Tree.XPPerPoint,
			Tree.XPPerPoint
		)
	for _, child in canvas:GetChildren() do
		child:Destroy()
	end
	table.clear(buttons)
	local wide = panel.AbsoluteSize.X >= 850
	local width = math.max(280, panel.AbsoluteSize.X - 24)
	local visible = if wide then Tree.Branches else { branch }
	for id, tab in tabs do
		tab.BackgroundTransparency = if id == branch or wide then 0 else 0.6
	end
	for index, id in visible do
		local columnWidth = width / #visible
		local column = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((index - 1) * columnWidth, 0),
			Size = UDim2.fromOffset(columnWidth, 490),
		}, canvas)
		local heading = text(column, Tree.BranchNames[id]:upper(), 12, colors[id], IronUi.Bold)
		heading.Position, heading.Size, heading.TextXAlignment =
			UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 24), Enum.TextXAlignment.Center
		local positions = {}
		for _, nodeId in Tree.Order[id] do
			local node = Tree.Nodes[nodeId]
			positions[nodeId] =
				Vector2.new(columnWidth * (if node.Column == 1 then 0.25 else 0.75), 38 + (node.Tier - 1) * 152 + 44)
		end
		for _, nodeId in Tree.Order[id] do
			local node = Tree.Nodes[nodeId]
			if node.Parent then
				line(
					column,
					positions[node.Parent],
					positions[nodeId],
					if data.Unlocked[nodeId] then colors[id] else Color3.fromRGB(64, 58, 80)
				)
			end
		end
		for _, nodeId in Tree.Order[id] do
			local node, center = Tree.Nodes[nodeId], positions[nodeId]
			local learned = data.Unlocked[nodeId]
			local available = not learned and (not node.Parent or data.Unlocked[node.Parent])
			local color = if learned then colors[id] elseif available then P.Text else P.Dim
			local button = new("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(center.X, center.Y),
				Size = UDim2.fromOffset(columnWidth * 0.43, 88),
				Text = "",
				BackgroundColor3 = if learned then Color3.fromRGB(43, 46, 57) else Color3.fromRGB(27, 24, 39),
				ZIndex = 2,
			}, column)
			UiKit.round(button, 10)
			new("UIStroke", { Color = color, Thickness = if nodeId == selected then 3 else 1 }, button)
			local name = text(button, node.Icon .. "\n" .. node.Name, 12, color, IronUi.Bold)
			name.Position, name.Size, name.TextWrapped, name.TextXAlignment, name.ZIndex =
				UDim2.fromOffset(6, 5), UDim2.new(1, -12, 0, 55), true, Enum.TextXAlignment.Center, 3
			local status = text(
				button,
				if learned
					then "UNLOCKED"
					elseif available then tostring(node.Cost) .. (if node.Cost == 1 then " POINT" else " POINTS")
					else "LOCKED",
				10,
				color
			)
			status.Position, status.Size, status.TextXAlignment, status.ZIndex =
				UDim2.fromOffset(4, 63), UDim2.new(1, -8, 0, 18), Enum.TextXAlignment.Center, 3
			buttons[nodeId] = button
			button.Activated:Connect(function()
				selected = nodeId
				updateDetail()
			end)
		end
	end
	updateDetail()
end
local function request(action, id)
	if busy or not canChange() then
		return
	end
	busy = true
	updateDetail()
	task.spawn(function()
		local result = GemClient.request(action, id)
		busy = false
		if result.Augments and GemClient.Profile then
			GemClient.Profile.Augments = result.Augments
		end
		UiKit.toast(result.Message, if result.Ok then P.Teal else UiKit.Colors.Bad)
		UI.refresh()
	end)
end
unlock.Activated:Connect(function()
	if unlock.Active then
		request("LearnAugment", selected)
	end
end)
reset.Activated:Connect(function()
	if reset.Active then
		request("ResetAugments")
	end
end)
function UI.isOpen()
	return gui.Enabled
end
function UI.open()
	gui.Enabled = true
	UI.refresh()
end
function UI.close()
	gui.Enabled = false
end
function UI.toggle()
	if gui.Enabled then
		UI.close()
	else
		UI.open()
	end
end
close.Activated:Connect(UI.close)
shade.Activated:Connect(UI.close)
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(UI.refresh)
GemClient.Changed:Connect(UI.refresh)
player:GetAttributeChangedSignal("CombatSession"):Connect(updateDetail)
player:GetAttributeChangedSignal("Expedition"):Connect(updateDetail)
return UI
