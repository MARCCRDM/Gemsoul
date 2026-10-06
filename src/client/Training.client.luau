--[[
	Combat training's panel (Shared.CombatTutorial; the server runs the
	lessons, see Duelist): which lesson you're on, what to press (in mouse and
	keys, or the on-screen buttons on a touch screen), how many of it you've
	done, a check when it's done, and SKIP TRAINING. The control the lesson
	is about pulses on screen (Combat's buttons tagged TutorialTarget).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Tutorial = require(ReplicatedStorage.Shared.CombatTutorial)
local GemClient = require(script.Parent.Modules.GemClient)
local HudChrome = require(script.Parent.Modules.HudChrome)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new
local GOLD, INK, TEXT = HudChrome.Gold, Color3.fromRGB(13, 16, 24), Color3.fromRGB(236, 240, 246)
local DIM, GREEN = Color3.fromRGB(150, 162, 180), Color3.fromRGB(96, 214, 128)

local gui = UiKit.gui("CombatTraining", 8)
gui.Enabled = false

local card = new("Frame", {
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.08,
	AnchorPoint = Vector2.new(0, 0),
	Size = UDim2.fromOffset(300, 132),
}, gui)
UiKit.round(card, 12)
local stroke = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.2 }, card)
local scale = new("UIScale", { Scale = 1 }, card)

local function label(text, size, color, font, y, height)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.fromOffset(14, y),
		Size = UDim2.new(1, -28, 0, height),
	}, card)
end
local header = label("COMBAT TRAINING", 11, GOLD, IronUi.Bold, 10, 14)
local title = label("", 20, TEXT, IronUi.Heading, 26, 24)
local body = label("", 13, DIM, IronUi.Body, 54, 44)
body.Font = Enum.Font.GothamMedium

-- Progress pips: one per hit / block / dodge the lesson asks for.
local pips = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 14, 1, -24),
	Size = UDim2.fromOffset(160, 12),
}, card)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, pips)

local skip = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -10, 1, -8),
	Size = UDim2.fromOffset(112, 22),
	BackgroundColor3 = Color3.fromRGB(32, 38, 52),
	Text = "SKIP TRAINING ›",
	TextSize = 11,
	Font = IronUi.Bold,
	TextColor3 = DIM,
	AutoButtonColor = true,
}, card)
UiKit.round(skip, 6)
skip.Activated:Connect(function()
	skip.Text = "SKIPPING…"
	GemClient.request("TutorialSkip")
end)

-- The pulse around the controls the lesson's about (up to three: Q, E, R).
local rings = {}
for i = 1, 3 do
	local ring = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 20,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	rings[i] = { Frame = ring, Stroke = new("UIStroke", { Color = GOLD, Thickness = 3 }, ring) }
end

local function touch(): boolean
	return UserInputService.TouchEnabled
end

-- Every on-screen control tagged for this lesson that's showing now.
local function targets(name: string?): { GuiObject }
	local found = {}
	local hud = player.PlayerGui:FindFirstChild("CombatHud")
	if not name or not hud or not hud.Enabled then
		return found
	end
	for _, d in hud:GetDescendants() do
		if d:IsA("GuiObject") and d:GetAttribute("TutorialTarget") == name and d.Visible and d.AbsoluteSize.X > 4 then
			local shown, node = true, d.Parent
			while node and node ~= hud do
				if node:IsA("GuiObject") and not node.Visible then
					shown = false
					break
				end
				node = node.Parent
			end
			if shown then
				table.insert(found, d)
			end
		end
	end
	return found
end

local shownStep, shownCount, doneAt = nil, nil, nil
local function refresh()
	local index = player:GetAttribute("TutorialStep")
	local step = Tutorial.step(index)
	gui.Enabled = step ~= nil
	if not step then
		shownStep = nil
		return
	end
	local count = player:GetAttribute("TutorialCount") or 0
	local goal = player:GetAttribute("TutorialGoal") or step.Goal
	if index ~= shownStep then
		shownStep, doneAt = index, nil
		header.Text = string.format("COMBAT TRAINING  ·  %d / %d", index, Tutorial.count())
		title.Text = step.Title
		body.Text = Tutorial.text(step, touch())
		skip.Visible = index < Tutorial.count()
		skip.Text = "SKIP TRAINING ›"
		stroke.Color, title.TextColor3 = GOLD, TEXT
		-- A fresh lesson pops in.
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if count ~= shownCount or #pips:GetChildren() - 1 ~= goal then
		shownCount = count
		for _, c in pips:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for i = 1, goal do
			local pip = new("Frame", {
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = if i <= count then GREEN else Color3.fromRGB(40, 46, 60),
				LayoutOrder = i,
			}, pips)
			UiKit.round(pip, 6)
			new("UIStroke", { Color = if i <= count then GREEN else Color3.fromRGB(80, 90, 110), Thickness = 1 }, pip)
		end
		pips.Visible = step.Event ~= "Win"
	end
	if count >= goal and step.Event ~= "Win" and not doneAt then
		-- Done: a green check, then the next lesson follows from the server.
		doneAt = os.clock()
		title.Text = "✓  " .. step.Title
		stroke.Color, title.TextColor3 = GREEN, GREEN
		scale.Scale = 1.06
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end
end
for _, name in { "TutorialStep", "TutorialCount", "TutorialGoal" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		for _, r in rings do
			r.Frame.Visible = false
		end
		return
	end
	-- Placement: top-left, clear of the corner buttons; smaller on phones.
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local phone = touch() and viewport.Y < 600
	card.Size = UDim2.fromOffset(if phone then 260 else 300, if phone then 118 else 132)
	body.TextSize = if phone then 12 else 13
	title.TextSize = if phone then 17 else 20
	card.Position = UDim2.fromOffset(if phone then 64 else 16, if phone then 96 else 110)
	-- The pulse: around the lesson's control, if it's on screen.
	local step = Tutorial.step(player:GetAttribute("TutorialStep"))
	local list = targets(step and not doneAt and step.Highlight)
	local pulse = (math.sin(os.clock() * 6) + 1) / 2
	for i, r in rings do
		local target = list[i]
		r.Frame.Visible = target ~= nil
		if target then
			local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) + 14 + pulse * 12
			local centre = target.AbsolutePosition + target.AbsoluteSize / 2
			r.Frame.Size = UDim2.fromOffset(size, size)
			r.Frame.Position = UDim2.fromOffset(centre.X, centre.Y)
			r.Stroke.Transparency = 0.1 + pulse * 0.5
		end
	end
end)
