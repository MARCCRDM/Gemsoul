-- Small helpers so every Saga Miners screen shares the same look.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.Colors = {
	Background = Color3.fromRGB(12, 10, 25),
	Row = Color3.fromRGB(36, 29, 52),
	Text = Color3.fromRGB(235, 242, 249),
	Dim = Color3.fromRGB(153, 172, 191),
	Accent = Color3.fromRGB(58, 203, 233),
	Gold = Color3.fromRGB(255, 202, 91),
	Bad = Color3.fromRGB(255, 90, 90),
}
local K = UiKit.Colors

function UiKit.gui(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order or 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function UiKit.round(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

function UiKit.pad(parent: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

function UiKit.list(parent: GuiObject, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	layout.Parent = parent
	return layout
end

-- A dark rounded panel with a glowing outline.
function UiKit.panel(parent: Instance, accent: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = K.Background
	frame.BackgroundTransparency = 0.06
	frame.Parent = parent
	UiKit.round(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Thickness = 1
	stroke.Transparency = 0.55
	stroke.Color = accent or K.Accent
	stroke.Parent = frame
	return frame
end

function UiKit.text(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = font or Enum.Font.Gotham
	label.TextSize = size
	label.TextColor3 = color or K.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UiKit.button(parent: Instance, text: string, color: Color3?, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.AutomaticSize = Enum.AutomaticSize.XY
	button.BackgroundColor3 = K.Row
	button.Font = Enum.Font.Gotham
	button.TextSize = 18
	button.TextColor3 = color or K.Text
	button.Text = text
	button.Parent = parent
	UiKit.round(button, 6)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button
	button.Activated:Connect(onClick)
	return button
end

-- A colour chip for a gem: its colour, a two-tone gradient for fusion
-- stones, or a shifting rainbow for prismatic ones.
function UiKit.swatch(parent: Instance, shade: { [string]: any }, size: number): Frame
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromOffset(size, size)
	chip.BackgroundColor3 = if shade.Color2 or shade.Prismatic then Color3.new(1, 1, 1) else shade.Color
	chip.Rotation = 45
	chip.Parent = parent
	UiKit.round(chip, 4)
	if shade.Color2 then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(shade.Color, shade.Color2)
		gradient.Parent = chip
	elseif shade.Prismatic then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, shade.Color),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(80, 200, 255)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 80, 220)),
			ColorSequenceKeypoint.new(1, shade.Color),
		})
		gradient.Parent = chip
		TweenService:Create(gradient, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Rotation = 360,
		}):Play()
	end
	return chip
end

-- Toasts: short messages that stack at the top of the screen and fade out.
local toastGui: ScreenGui? = nil
local toastHolder: Frame? = nil

function UiKit.toast(message: string, color: Color3?)
	if not toastHolder then
		toastGui = UiKit.gui("Toasts", 20)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 56)
		holder.Size = UDim2.new(0.9, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = toastGui
		local layout = UiKit.list(holder, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		toastHolder = holder
	end
	-- A chunky dark pill: coloured rim and edge stripe, white outlined text.
	-- It pops in, then fades and floats away.
	local accent = color or K.Gold
	local toast = Instance.new("Frame")
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.Size = UDim2.fromOffset(0, 0)
	toast.BackgroundColor3 = Color3.new(1, 1, 1)
	toast.Parent = toastHolder
	UiKit.round(toast, 14)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(K.Row, K.Background)
	shade.Parent = toast
	local rim = Instance.new("UIStroke")
	rim.Color = accent
	rim.Thickness = 1
	rim.Transparency = 0.5
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = toast
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 26)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = toast
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(620, math.huge)
	constraint.Parent = toast
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = accent
	stripe.Position = UDim2.new(0, -18, 0, -2)
	stripe.Size = UDim2.new(0, 6, 1, 4)
	stripe.Parent = toast
	UiKit.round(stripe, 3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(0, 0)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = message
	label.TextWrapped = false
	label.Parent = toast
	local ink = Instance.new("UIStroke")
	ink.Color = Color3.fromRGB(12, 8, 18)
	ink.Thickness = 1
	ink.Transparency = 1
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ink.Parent = label
	local pop = Instance.new("UIScale")
	pop.Scale = 0.6
	pop.Parent = toast
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(4, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stripe, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(ink, fade, { Transparency = 1 }):Play()
		TweenService:Create(rim, fade, { Transparency = 1 }):Play()
		TweenService:Create(pop, fade, { Scale = 0.9 }):Play()
		task.wait(0.5)
		toast:Destroy()
	end)
end

return UiKit
