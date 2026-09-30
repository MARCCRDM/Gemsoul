--[[
	Gemsoul's menu style, shared by every window: dark crystal panels with
	gold trim, gradient header bars, chunky outlined titles, and buttons that
	bounce when you hover and press them. Windows pop open.

	Builders: new, text, title (chunky outlined text), box, button,
	gemButton (a big coloured buy button with a moving shine), tabs, badge,
	juice (hover/press bounce for anything), shine, clear, window.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)

local IronUi = {}

IronUi.Colors = {
	Frame = Color3.fromRGB(16, 13, 22),
	Inset = Color3.fromRGB(26, 22, 34),
	Slot = Color3.fromRGB(34, 30, 44),
	Edge = Color3.fromRGB(110, 86, 52),
	Gold = Color3.fromRGB(240, 196, 92),
	Text = Color3.fromRGB(236, 230, 214),
	Dim = Color3.fromRGB(160, 150, 136),
	Good = Color3.fromRGB(90, 220, 120),
	Bad = Color3.fromRGB(235, 90, 80),
	Amethyst = Color3.fromRGB(130, 60, 210),
	Teal = Color3.fromRGB(20, 150, 170),
	Emerald = Color3.fromRGB(40, 200, 110),
	Ink = Color3.fromRGB(12, 8, 18), -- outlines on chunky text
}
local P = IronUi.Colors

IronUi.Heading = Enum.Font.LuckiestGuy -- big titles
IronUi.Chunky = Enum.Font.FredokaOne -- buttons, tabs, labels that should pop
IronUi.Body = Enum.Font.Gotham
IronUi.Bold = Enum.Font.GothamBold

local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function IronUi.new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end
local new = IronUi.new

-- True while a piece of UI is still in the game (false once destroyed).
local function alive(object: Instance): boolean
	local ok, parent = pcall(function()
		return object.Parent
	end)
	return ok and parent ~= nil
end
IronUi.alive = alive

-- One shared per-frame loop for all the little idle animations (bobbing,
-- wobbling, floating) instead of a loop per element. step(t) gets the clock;
-- the entry drops out on its own once `object` is destroyed.
local animations: { [Instance]: (number) -> () } = {}
local animating = false
function IronUi.animate(object: Instance, step: (number) -> ())
	animations[object] = step
	if animating then
		return
	end
	animating = true
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for target, fn in animations do
			if not alive(target) then
				animations[target] = nil
			else
				fn(now)
			end
		end
	end)
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

function IronUi.text(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = new("TextLabel", {
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
	-- Display fonts get an ink outline so they read on any background.
	if font == IronUi.Heading or font == IronUi.Chunky then
		IronUi.outline(label, if size >= 24 then 3 else 2)
	end
	return label
end

-- An outline around text (not the box).
function IronUi.outline(label: TextLabel | TextButton, thickness: number?, color: Color3?)
	new("UIStroke", {
		Color = color or P.Ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, label)
end

-- Puts outlined text inside a button (a button's own text can't have both a
-- box outline and a text outline). Returns the label.
function IronUi.inner(b: TextButton, value: string, font: Enum.Font, size: number, color: Color3): TextLabel
	b.Text = ""
	local label = new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = value,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		ZIndex = b.ZIndex + 2,
	}, b)
	IronUi.outline(label, 2)
	return label
end

-- Chunky outlined text, for titles and prices.
function IronUi.title(parent: Instance, value: string, size: number, color: Color3?): TextLabel
	return IronUi.text(parent, value, size, color or Color3.new(1, 1, 1), IronUi.Heading)
end

-- Bounce on hover and press. Works on any button.
function IronUi.juice(guiButton: GuiButton, hoverScale: number?)
	local scale = guiButton:FindFirstChildOfClass("UIScale") or new("UIScale", {}, guiButton)
	local hover = hoverScale or 1.06
	local function to(value: number, time: number?)
		TweenService:Create(scale, TweenInfo.new(time or 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = value,
		}):Play()
	end
	guiButton.MouseEnter:Connect(function()
		to(hover)
	end)
	guiButton.MouseLeave:Connect(function()
		to(1)
	end)
	guiButton.MouseButton1Down:Connect(function()
		to(0.92, 0.06)
	end)
	guiButton.MouseButton1Up:Connect(function()
		to(hover)
	end)
end

-- A band of light that sweeps across `object` every few seconds.
function IronUi.shine(object: GuiObject, every: number?)
	object.ClipsDescendants = true
	local sweep = new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = object.ZIndex + 1,
	}, object)
	local gradient = new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
	}, sweep)
	task.spawn(function()
		while alive(sweep) do
			gradient.Offset = Vector2.new(-1, 0)
			TweenService:Create(gradient, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
				:Play()
			task.wait((every or 2.8) + math.random())
		end
	end)
end

-- A panel: dark crystal fill, gold edge, lighter at the top.
function IronUi.box(parent: Instance, position: UDim2, size: UDim2, fill: Color3?, radius: number?): Frame
	local frame = new("Frame", { BackgroundColor3 = fill or P.Inset, Position = position, Size = size }, parent)
	UiKit.round(frame, radius or 10)
	new("UIStroke", { Color = P.Edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165)),
	}, frame)
	return frame
end

-- A pill button: gold for the main action, slate for the rest.
function IronUi.button(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = if primary then P.Gold else P.Slot,
		Text = label,
		Font = IronUi.Chunky,
		TextSize = 15,
		TextColor3 = if primary then Color3.fromRGB(40, 24, 8) else P.Text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
	}, parent)
	corner(b, UDim.new(0.5, 0))
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
	}, b)
	new("UIStroke", {
		Color = if primary then Color3.fromRGB(120, 80, 20) else P.Edge,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, b)
	IronUi.juice(b)
	b.Activated:Connect(onClick)
	return b
end

-- A big coloured buy button with white outlined text and a moving shine.
function IronUi.gemButton(parent: Instance, label: string, color: Color3?, onClick: () -> ()): TextButton
	local fill = color or P.Emerald
	local b = new("TextButton", {
		BackgroundColor3 = fill,
		Text = label, -- sets the width; the visible text is the outlined label
		Font = IronUi.Chunky,
		TextSize = 18,
		TextTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		AutoButtonColor = true,
	}, parent)
	corner(b, UDim.new(0, 10))
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(fill:Lerp(Color3.new(1, 1, 1), 0.35), fill:Lerp(Color3.new(0, 0, 0), 0.25)),
	}, b)
	new("UIStroke", {
		Color = fill:Lerp(Color3.new(0, 0, 0), 0.55),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, b)
	local text = new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = label,
		Font = IronUi.Chunky,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = b.ZIndex + 2,
	}, b)
	IronUi.outline(text, 2)
	IronUi.shine(b)
	IronUi.juice(b, 1.07)
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

-- A row of chunky pill tabs; `entries` are { Id, Label }. Returns the row.
function IronUi.tabs(parent: Instance, entries: { { string } }, active: string, onPick: (string) -> ()): Frame
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
	}, parent)
	UiKit.list(row, 8, true)
	for i, entry in entries do
		local on = entry[1] == active
		local tab = new("TextButton", {
			Text = entry[2],
			Font = IronUi.Chunky,
			TextSize = 15,
			BackgroundColor3 = if on then P.Amethyst else P.Slot,
			TextColor3 = if on then Color3.new(1, 1, 1) else P.Dim,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = i,
		}, row)
		corner(tab, UDim.new(0.5, 0))
		new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, tab)
		new("UIStroke", {
			Color = if on then P.Gold else P.Edge,
			Thickness = if on then 2.5 else 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, tab)
		if on then
			new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(200, 150, 255), Color3.fromRGB(110, 60, 170)),
			}, tab)
			-- Keep the width from the text, show an outlined copy on top.
			tab.TextTransparency = 1
			local shown = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = entry[2],
				Font = IronUi.Chunky,
				TextSize = 15,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = tab.ZIndex + 1,
			}, tab)
			IronUi.outline(shown, 2)
		end
		IronUi.juice(tab)
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
	corner(badge, UDim.new(0.5, 0))
	new("UIStroke", { Color = P.Ink, Thickness = 3 }, badge)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140)),
	}, badge)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = icon,
		TextSize = math.floor(size * 0.55),
		Font = IronUi.Chunky,
		TextColor3 = Color3.new(1, 1, 1),
	}, badge)
	return badge
end

export type Window = {
	Gui: ScreenGui,
	Panel: Frame,
	Header: Frame,
	Scale: UIScale,
	Shade: TextButton,
	Close: TextButton,
	Title: TextLabel,
	Subtitle: TextLabel,
	Fit: () -> (),
}

--[[
	A hidden full-screen window: dimmed backdrop, a panel of a fixed design
	size scaled to fit the screen, a gradient header bar (in `accent`) with a
	chunky outlined title, an icon badge popping out of the corner and a red
	close button. It pops open whenever it's enabled.
]]
function IronUi.window(
	name: string,
	order: number,
	width: number,
	height: number,
	icon: string?,
	accent: Color3?
): Window
	local color = accent or P.Amethyst
	local gui = UiKit.gui(name, order)
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	local shade = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, gui)
	UiKit.round(panel, 16)
	-- A thick gold rim, and a dark crystal body fading down.
	new("UIStroke", { Color = P.Gold, Thickness = 4 }, panel)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(34, 26, 48), P.Frame),
	}, panel)
	local rim = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
	}, panel)
	UiKit.round(rim, 12)
	new("UIStroke", { Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Thickness = 1.5, Transparency = 0.5 }, rim)

	-- Header bar.
	local header = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 0, 62),
	}, panel)
	UiKit.round(header, 12)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.1)),
			ColorSequenceKeypoint.new(0.6, color:Lerp(Color3.new(0, 0, 0), 0.25)),
			ColorSequenceKeypoint.new(1, P.Teal:Lerp(Color3.new(0, 0, 0), 0.3)),
		}),
	}, header)
	-- A strip of light along the top edge of the bar.
	local gloss = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 10),
	}, header)
	UiKit.round(gloss, 5)

	local scale = new("UIScale", {}, panel)
	local target = 1
	local popping = false
	local function fit()
		local screen = gui.AbsoluteSize
		target = math.min(1, (screen.X - 40) / width, (screen.Y - 40) / height)
		if not popping then
			scale.Scale = target
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	-- Pop open (and fade the backdrop in) every time the window is shown.
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			return
		end
		fit()
		popping = true
		scale.Scale = target * 0.7
		shade.BackgroundTransparency = 1
		TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = target }
		)
		tween.Completed:Connect(function()
			popping = false
			scale.Scale = target
		end)
		tween:Play()
	end)

	-- The icon badge pops out of the top-left corner; the title moves over.
	local left = 24
	if icon then
		local badge = IronUi.badge(panel, icon, 84)
		badge.Position = UDim2.fromOffset(-26, -28)
		badge.Rotation = -8
		badge.ZIndex = 5
		for _, child in badge:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 6
			end
		end
		left = 72
	end
	local title = IronUi.title(panel, "", 30)
	title.Position = UDim2.fromOffset(left, 12)
	title.Size = UDim2.new(0.6, 0, 0, 32)
	title.ZIndex = 3
	local subtitle = IronUi.text(panel, "", 13, Color3.fromRGB(240, 230, 255), IronUi.Bold)
	subtitle.Position = UDim2.fromOffset(left + 2, 44)
	subtitle.Size = UDim2.new(0.62, 0, 0, 16)
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle.AutomaticSize = Enum.AutomaticSize.None
	subtitle.ZIndex = 3

	-- A chunky red close button on the top-right corner.
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(230, 60, 60),
		Text = "X",
		Font = IronUi.Heading,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
	}, panel)
	corner(close, UDim.new(0.5, 0))
	new("UIStroke", { Color = P.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 170), Color3.fromRGB(170, 60, 60)),
	}, close)
	IronUi.inner(close, "X", IronUi.Heading, 24, Color3.new(1, 1, 1)).ZIndex = 7
	IronUi.juice(close, 1.12)

	return {
		Gui = gui,
		Panel = panel,
		Header = header,
		Scale = scale,
		Shade = shade,
		Close = close,
		Title = title,
		Subtitle = subtitle,
		Fit = fit,
	}
end

return IronUi
