--[[
	Gemsoul's menu style, shared by every window: dark crystal panels with
	gold trim, gradient header bars, chunky outlined titles, and buttons that
	bounce when you hover and press them. Windows pop open.

	Buttons are "chunks": thick 3D slabs like a toy. From the outside in:
	a black outline, a darker lip underneath (the depth), a light rim, then a
	gradient face with a glossy top, diagonal light stripes and an optional
	halftone dot texture. Icons are drawn big and break out of the edge.
	Pressing one sinks the face into its lip.

	Builders: new, text, title (chunky outlined text), box, chunk (the 3D
	slab), label (outlined text on a chunk's face), button, gemButton, tabs,
	badge, juice (hover/press bounce), shine, animate, clear, window.
]]
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
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
function IronUi.juice(guiButton: GuiButton, hoverScale: number?, pressScale: number?)
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
		to(pressScale or 0.92, 0.06)
	end)
	guiButton.MouseButton1Up:Connect(function()
		to(hover)
	end)
end

-- A band of light that sweeps across `object` every few seconds.
function IronUi.shine(object: GuiObject, every: number?)
	-- Clipped in its own layer, so icons can still break out of `object`.
	local clip = new("Frame", {
		Name = "ShineClip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = object.ZIndex + 1,
	}, object)
	local sweep = new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
	}, clip)
	local round = object:FindFirstChildOfClass("UICorner")
	if round then
		corner(sweep, round.CornerRadius)
	end
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

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end
local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end
IronUi.lighter, IronUi.darker = lighter, darker

-- Hard-edged bands of light for a UIGradient: { {from, to, transparency} }.
local function bands(list: { { number } }): NumberSequence
	local points = { NumberSequenceKeypoint.new(0, 1) }
	for _, band in list do
		table.insert(points, NumberSequenceKeypoint.new(band[1], 1))
		table.insert(points, NumberSequenceKeypoint.new(band[1] + 0.001, band[3]))
		table.insert(points, NumberSequenceKeypoint.new(band[2], band[3]))
		table.insert(points, NumberSequenceKeypoint.new(band[2] + 0.001, 1))
	end
	table.insert(points, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(points)
end
local THIN_STRIPES = bands({ { 0.56, 0.64, 0.8 }, { 0.7, 0.74, 0.84 } })
local BROAD_STRIPES = bands({ { 0.18, 0.34, 0.8 }, { 0.44, 0.52, 0.84 }, { 0.72, 0.9, 0.8 } })

-- Rows of little diamonds, offset every other row: a halftone texture.
local DOT_ROWS = (function()
	local rows = {}
	for i = 1, 8 do
		table.insert(rows, (if i % 2 == 0 then "  " else "") .. string.rep("◆   ", 14))
	end
	return table.concat(rows, "\n")
end)()

export type ChunkOptions = {
	Color: Color3, -- the face colour
	Size: UDim2?,
	Radius: number?, -- corner size in pixels (default 12)
	Lip: number?, -- how thick the slab looks (default 5)
	Rim: Color3?, -- the light edge around the face
	Stripes: ("Thin" | "Broad" | "None")?, -- diagonal light (default Thin)
	Dots: boolean?, -- a halftone texture fading in from the right
	PadX: number?, -- side padding, for buttons sized by their text
}

--[[
	A 3D button slab. Returns the button and its face (put icons and labels
	on the face so they sink with it when pressed).
]]
function IronUi.chunk(parent: Instance, options: ChunkOptions): (TextButton, Frame)
	local fill = options.Color
	local radius = options.Radius or 12
	local lip = options.Lip or 5
	local pad = options.PadX or 0
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = darker(fill, 0.5),
		Size = options.Size or UDim2.fromOffset(120, 46),
	}, parent)
	corner(b, UDim.new(0, radius))
	new("UIStroke", {
		Color = P.Ink,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, b)
	-- Buttons sized by their text: IronUi.label sets the width (text + pad
	-- on each side). No AutomaticSize: the slab's layers fill the button,
	-- and letting them size it makes it grow forever.
	if pad > 0 then
		b:SetAttribute("PadX", pad)
	end
	-- The rim sits on top of the lip; pressing slides it down over the lip.
	local rim = new("Frame", {
		Name = "Rim",
		BackgroundColor3 = options.Rim or lighter(fill, 0.55),
		Size = UDim2.new(1, 0, 1, -lip),
	}, b)
	corner(rim, UDim.new(0, radius))
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
	}, rim)
	corner(face, UDim.new(0, math.max(3, radius - 3)))
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(lighter(fill, 0.2), darker(fill, 0.15)),
	}, face)
	-- Halftone dots, strongest at the right edge.
	if options.Dots then
		local clip = new("Frame", {
			Name = "Dots",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(radius / 2, radius / 2),
			Size = UDim2.new(1, -radius, 1, -radius),
		}, face)
		local dots = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = DOT_ROWS,
			TextSize = 7,
			LineHeight = 1.2,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, clip)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, 1),
				NumberSequenceKeypoint.new(1, 0.55),
			}),
		}, dots)
	end
	-- Diagonal stripes of light.
	local stripes = options.Stripes or "Thin"
	if stripes ~= "None" then
		local layer = new("Frame", {
			Name = "Stripes",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 1),
		}, face)
		corner(layer, UDim.new(0, math.max(3, radius - 3)))
		new("UIGradient", {
			Rotation = -35,
			Transparency = if stripes == "Broad" then BROAD_STRIPES else THIN_STRIPES,
		}, layer)
	end
	-- Gloss over the top half.
	local gloss = new("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0.46, -2),
	}, face)
	corner(gloss, UDim.new(0, math.max(3, radius - 5)))
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(0.62, 0.9),
	}, gloss)

	-- Hover grows it; pressing sinks the face into the lip.
	IronUi.juice(b, 1.05, 0.97)
	local up, down = rim.Position, UDim2.fromOffset(0, lip - 1)
	local function sink(pressed: boolean)
		TweenService:Create(rim, TweenInfo.new(0.06), { Position = if pressed then down else up }):Play()
	end
	b.MouseButton1Down:Connect(function()
		sink(true)
	end)
	b.MouseButton1Up:Connect(function()
		sink(false)
	end)
	b.MouseLeave:Connect(function()
		sink(false)
	end)
	return b, face
end

-- Big outlined text on a chunk's face. It follows the button's own Text and
-- TextSize, so code can keep setting those.
function IronUi.label(b: TextButton, face: Frame, value: string, size: number, font: Enum.Font?): TextLabel
	b.Text = value
	b.TextSize = size
	b.Font = font or IronUi.Chunky
	b.TextTransparency = 1
	local label = new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = value,
		TextSize = size,
		Font = font or IronUi.Chunky,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = false,
	}, face)
	IronUi.outline(label, if size >= 22 then 3 else 2)
	-- Text-sized buttons (see chunk's PadX) keep their width fitted to the
	-- words; a width set by scale (e.g. full-width) is left alone.
	local pad = b:GetAttribute("PadX")
	local function fit()
		if not pad or b.Size.X.Scale ~= 0 then
			return
		end
		local ok, bounds = pcall(function()
			return TextService:GetTextSize(b.Text, b.TextSize, b.Font, Vector2.new(10000, 10000))
		end)
		local width = math.ceil((if ok then bounds.X else #b.Text * b.TextSize * 0.6) + pad * 2)
		if b.Size.X.Offset ~= width then
			b.Size = UDim2.new(0, width, b.Size.Y.Scale, b.Size.Y.Offset)
		end
	end
	b:GetPropertyChangedSignal("Text"):Connect(function()
		label.Text = b.Text
		fit()
	end)
	b:GetPropertyChangedSignal("TextSize"):Connect(function()
		label.TextSize = b.TextSize
		fit()
	end)
	b:GetPropertyChangedSignal("Size"):Connect(fit)
	fit()
	return label
end

local SLATE = Color3.fromRGB(88, 80, 112)

-- A chunky pill button: gold for the main action, slate for the rest.
function IronUi.button(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b, face = IronUi.chunk(parent, {
		Color = if primary then Color3.fromRGB(250, 186, 40) else SLATE,
		Rim = if primary then Color3.fromRGB(255, 236, 150) else Color3.fromRGB(170, 162, 196),
		Size = UDim2.fromOffset(0, 40),
		Radius = 10,
		Lip = 4,
		PadX = 16,
		Stripes = if primary then "Thin" else "None",
	})
	IronUi.label(b, face, label, 15)
	b.Activated:Connect(onClick)
	return b
end

-- A big coloured buy button: stripes, dots and a moving shine.
function IronUi.gemButton(parent: Instance, label: string, color: Color3?, onClick: () -> ()): TextButton
	local b, face = IronUi.chunk(parent, {
		Color = color or P.Emerald,
		Size = UDim2.fromOffset(0, 48),
		Radius = 12,
		Lip = 6,
		PadX = 18,
		Dots = true,
	})
	IronUi.label(b, face, label, 19)
	IronUi.shine(face)
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

-- A row of chunky tabs; `entries` are { Id, Label }. Returns the row.
function IronUi.tabs(parent: Instance, entries: { { string } }, active: string, onPick: (string) -> ()): Frame
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 44),
	}, parent)
	UiKit.list(row, 8, true)
	for i, entry in entries do
		local on = entry[1] == active
		local tab, face = IronUi.chunk(row, {
			Color = if on then P.Amethyst else Color3.fromRGB(52, 46, 68),
			Rim = if on then Color3.fromRGB(214, 180, 255) else Color3.fromRGB(96, 88, 120),
			Size = UDim2.fromOffset(0, if on then 42 else 38),
			Radius = 10,
			Lip = if on then 5 else 4,
			PadX = 16,
			Stripes = if on then "Thin" else "None",
			Dots = on,
		})
		tab.LayoutOrder = i
		local label = IronUi.label(tab, face, entry[2], 15)
		if not on then
			label.TextColor3 = Color3.fromRGB(196, 186, 220)
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
	local close, closeFace = IronUi.chunk(panel, {
		Color = Color3.fromRGB(232, 58, 58),
		Size = UDim2.fromOffset(50, 50),
		Radius = 14,
		Lip = 6,
		Stripes = "None",
	})
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.ZIndex = 5
	IronUi.label(close, closeFace, "X", 26, IronUi.Heading)

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
