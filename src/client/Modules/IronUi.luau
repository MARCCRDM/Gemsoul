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
	UiKit.round(b, 6)
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
function IronUi.window(name: string, order: number, width: number, height: number): Window
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

	local title = IronUi.text(panel, "", 24, P.Gold, IronUi.Heading)
	title.Position = UDim2.fromOffset(24, 16)
	title.Size = UDim2.new(0.5, 0, 0, 26)
	local subtitle = IronUi.text(panel, "", 14, P.Dim, IronUi.Bold)
	subtitle.Position = UDim2.fromOffset(24, 44)
	subtitle.Size = UDim2.new(0.5, 0, 0, 18)

	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = P.Slot,
		Text = "X",
		Font = IronUi.Bold,
		TextSize = 18,
		TextColor3 = P.Gold,
	}, panel)
	UiKit.round(close, 6)
	new("UIStroke", { Color = P.Edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)

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
