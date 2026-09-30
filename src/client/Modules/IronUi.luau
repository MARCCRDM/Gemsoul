--[[
	The dark iron and old gold look shared by the character screen and the
	forge: a palette, small builders and a centred, auto-scaling window.
]]
local UiKit = require(script.Parent.UiKit)

local IronUi = {}

IronUi.Colors = {
	Frame = Color3.fromRGB(14, 13, 12),
	Inset = Color3.fromRGB(22, 20, 18),
	Slot = Color3.fromRGB(28, 25, 22),
	Edge = Color3.fromRGB(92, 72, 44),
	Gold = Color3.fromRGB(214, 170, 92),
	Text = Color3.fromRGB(226, 218, 200),
	Dim = Color3.fromRGB(150, 140, 122),
	Good = Color3.fromRGB(120, 220, 120),
	Bad = Color3.fromRGB(235, 90, 80),
}
local P = IronUi.Colors

IronUi.Heading = Enum.Font.Arcade
IronUi.Body = Enum.Font.Gotham
IronUi.Bold = Enum.Font.GothamBold

function IronUi.new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end
local new = IronUi.new

function IronUi.text(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or IronUi.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
end

-- A bevelled box: dark fill, bronze edge, lighter at the top.
function IronUi.box(parent: Instance, position: UDim2, size: UDim2, fill: Color3?, radius: number?): Frame
	local frame = new("Frame", { BackgroundColor3 = fill or P.Inset, Position = position, Size = size }, parent)
	UiKit.round(frame, radius or 6)
	new("UIStroke", { Color = P.Edge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
	}, frame)
	return frame
end

function IronUi.button(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = if primary then P.Gold else P.Slot,
		Text = label,
		Font = IronUi.Bold,
		TextSize = 14,
		TextColor3 = if primary then Color3.fromRGB(24, 18, 10) else P.Text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
	}, parent)
	-- Pill-shaped, with a soft highlight along the top.
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
	}, b)
	new("UIStroke", { Color = P.Edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, b)
	b.Activated:Connect(onClick)
	return b
end

-- Removes children except layout pieces (lists, corners, outlines, padding).
function IronUi.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

export type Window = {
	Gui: ScreenGui,
	Panel: Frame,
	Scale: UIScale,
	Shade: TextButton,
	Close: TextButton,
	Title: TextLabel,
	Subtitle: TextLabel,
	Fit: () -> (),
}

-- A hidden full-screen window: dimmed backdrop, gold-edged panel of a fixed
-- design size scaled to fit the screen, a title, subtitle and close button.
-- A row of pill tabs; `entries` are { Id, Label }. Returns the row.
function IronUi.tabs(parent: Instance, entries: { { string } }, active: string, onPick: (string) -> ()): Frame
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 32),
	}, parent)
	UiKit.list(row, 8, true)
	for i, entry in entries do
		local on = entry[1] == active
		local tab = new("TextButton", {
			Text = entry[2],
			Font = IronUi.Bold,
			TextSize = 13,
			BackgroundColor3 = if on then P.Gold else P.Slot,
			TextColor3 = if on then Color3.fromRGB(24, 18, 10) else P.Dim,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			LayoutOrder = i,
		}, row)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = tab
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, tab)
		if not on then
			new("UIStroke", { Color = P.Edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tab)
		end
		tab.Activated:Connect(function()
			onPick(entry[1])
		end)
	end
	return row
end

-- A round badge with an icon (an emoji works well), e.g. on a window's corner.
function IronUi.badge(parent: Instance, icon: string, size: number, color: Color3?): Frame
	local badge = new("Frame", {
		BackgroundColor3 = color or P.Gold,
		Size = UDim2.fromOffset(size, size),
	}, parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	new("UIStroke", { Color = P.Frame, Thickness = 3 }, badge)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
	}, badge)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = icon,
		TextSize = math.floor(size * 0.55),
		Font = IronUi.Bold,
		TextColor3 = Color3.new(1, 1, 1),
	}, badge)
	return badge
end

function IronUi.window(name: string, order: number, width: number, height: number, icon: string?): Window
	local gui = UiKit.gui(name, order)
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	local shade = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = P.Frame,
	}, gui)
	UiKit.round(panel, 10)
	new("UIStroke", { Color = P.Gold, Thickness = 2.5 }, panel)
	local scale = new("UIScale", {}, panel)
	local function fit()
		local screen = gui.AbsoluteSize
		scale.Scale = math.min(1, (screen.X - 24) / width, (screen.Y - 24) / height)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	-- The icon badge sits over the top-left corner; the title moves over.
	local left = 24
	if icon then
		local badge = IronUi.badge(panel, icon, 62)
		badge.Position = UDim2.fromOffset(-18, -18)
		badge.ZIndex = 5
		for _, child in badge:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 6
			end
		end
		left = 56
	end
	local title = IronUi.text(panel, "", 24, P.Gold, IronUi.Heading)
	title.Position = UDim2.fromOffset(left, 16)
	title.Size = UDim2.new(0.5, 0, 0, 26)
	local subtitle = IronUi.text(panel, "", 14, P.Dim, IronUi.Bold)
	subtitle.Position = UDim2.fromOffset(left, 44)
	subtitle.Size = UDim2.new(0.5, 0, 0, 18)

	-- A round red close button on the top-right corner.
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(220, 60, 60),
		Text = "X",
		Font = IronUi.Bold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
	}, panel)
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0.5, 0)
	closeCorner.Parent = close
	new("UIStroke", { Color = P.Frame, Thickness = 3 }, close)

	return {
		Gui = gui,
		Panel = panel,
		Scale = scale,
		Shade = shade,
		Close = close,
		Title = title,
		Subtitle = subtitle,
		Fit = fit,
	}
end

return IronUi
