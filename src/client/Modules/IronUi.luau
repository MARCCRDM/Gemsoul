-- Expedition UI: obsidian metal, jewel accents, luminous interaction and clear typography.
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)

local IronUi = {}

IronUi.Colors = {
	Frame = Color3.fromRGB(12, 10, 25),
	Inset = Color3.fromRGB(26, 22, 43),
	Slot = Color3.fromRGB(40, 33, 61),
	Edge = Color3.fromRGB(99, 83, 137), -- subdued station border
	Gold = Color3.fromRGB(255, 202, 91), -- Saga amber
	Text = Color3.fromRGB(235, 242, 249),
	Dim = Color3.fromRGB(177, 193, 216),
	Good = Color3.fromRGB(90, 220, 150),
	Bad = Color3.fromRGB(240, 92, 92),
	Amethyst = Color3.fromRGB(150, 76, 221),
	Teal = Color3.fromRGB(58, 203, 233),
	Emerald = Color3.fromRGB(34, 207, 157),
	Ink = Color3.fromRGB(3, 5, 12), -- outlines on display text
}
local P = IronUi.Colors

IronUi.Heading = Enum.Font.GothamBold -- clear, compact headings
IronUi.Chunky = Enum.Font.GothamMedium -- controls and labels
IronUi.Body = Enum.Font.Gotham
IronUi.Bold = Enum.Font.GothamBold

function IronUi.new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	if object:IsA("GuiObject") then
		object.BorderSizePixel = 0
	end
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
				local screen = target:FindFirstAncestorWhichIsA("ScreenGui")
				if not screen or screen.Enabled then
					fn(now)
				end
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
	return label
end

-- An outline around text (not the box).
function IronUi.outline(label: TextLabel | TextButton, thickness: number?, color: Color3?)
	new("UIStroke", {
		Color = color or P.Ink,
		Thickness = thickness or 1,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, label)
end

-- Separate button label, independent of the surface border.
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
	return label
end

-- Clear display text for titles and prices.
function IronUi.title(parent: Instance, value: string, size: number, color: Color3?): TextLabel
	return IronUi.text(parent, value, size, color or Color3.new(1, 1, 1), IronUi.Heading)
end

-- Code-native wordmark: gold face over stepped magenta and violet depth.
function IronUi.wordmark(parent: Instance): Frame
	local mark = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 40) }, parent)
	local function layer(x, y, color)
		return new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(330, 34),
			Text = "SAGA MINERS",
			Font = Enum.Font.Arcade,
			TextSize = 30,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, mark)
	end
	layer(0, 6, Color3.fromRGB(59, 27, 109))
	layer(0, 4, Color3.fromRGB(143, 43, 136))
	layer(0, 2, Color3.fromRGB(213, 103, 52))
	local face = layer(0, 0, Color3.new(1, 1, 1))
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 185)),
			ColorSequenceKeypoint.new(0.48, P.Gold),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(229, 143, 44)),
		}),
	}, face)
	return mark
end

-- Bounce on hover and press. Works on any button.
function IronUi.juice(guiButton: GuiButton, hoverScale: number?, pressScale: number?)
	local scale = guiButton:FindFirstChildOfClass("UIScale") or new("UIScale", {}, guiButton)
	local hover = hoverScale or 1.03
	local function to(value: number, time: number?)
		TweenService:Create(scale, TweenInfo.new(time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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
		to(pressScale or 0.97, 0.06)
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

-- Native geometric emblems keep the menu sharp at every resolution.
function IronUi.emblem(parent: Instance, kind: string, color: Color3, size: number): Frame
	local canvas = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) }, parent)
	local function bar(x, y, w, h, rotation)
		return new("Frame", {
			BackgroundColor3 = color,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rotation or 0,
		}, canvas)
	end
	local function outline(x, y, w, h, rotation)
		local piece = bar(x, y, w, h, rotation)
		piece.BackgroundTransparency = 1
		new("UIStroke", { Color = color, Thickness = 1.5 }, piece)
		return piece
	end
	if kind == "Trade" then
		bar(0.18, 0.3, 0.62, 0.055)
		bar(0.65, 0.21, 0.2, 0.055, 45)
		bar(0.65, 0.39, 0.2, 0.055, -45)
		bar(0.18, 0.66, 0.62, 0.055)
		bar(0.12, 0.57, 0.2, 0.055, -45)
		bar(0.12, 0.75, 0.2, 0.055, 45)
	elseif kind == "Enchant" then
		outline(0.34, 0.34, 0.32, 0.32, 45)
		for _, spec in
			{
				{ 0.49, 0.08, 0.03, 0.18 },
				{ 0.49, 0.74, 0.03, 0.18 },
				{ 0.08, 0.49, 0.18, 0.03 },
				{ 0.74, 0.49, 0.18, 0.03 },
			}
		do
			bar(spec[1], spec[2], spec[3], spec[4])
		end
	elseif kind == "Equipment" then
		outline(0.22, 0.18, 0.56, 0.48)
		bar(0.32, 0.72, 0.36, 0.055)
		bar(0.4, 0.81, 0.2, 0.055)
		bar(0.47, 0.3, 0.06, 0.26)
	else
		for i = 0, 2 do
			local coin = outline(0.2 + i * 0.1, 0.17 + i * 0.16, 0.45, 0.3)
			corner(coin, UDim.new(1, 0))
		end
	end
	return canvas
end

-- Orbital display decoration, shared by character and gemstone stages.
function IronUi.orbit(parent: GuiObject, color: Color3, diameter: number)
	for index, scale in { 1, 0.78 } do
		local ring = new("Frame", {
			Name = "OrbitRing",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(diameter * scale, diameter * scale),
		}, parent)
		corner(ring, UDim.new(1, 0))
		new("UIStroke", { Color = color, Thickness = if index == 1 then 2 else 1, Transparency = 0.65 }, ring)
		local satellite = new("Frame", {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			Rotation = 45,
		}, ring)
		corner(satellite, UDim.new(0, 1))
		IronUi.animate(ring, function(t)
			ring.Rotation = (t * (if index == 1 then 9 else -13)) % 360
		end)
	end
end

-- A panel: dark crystal fill, gold edge, lighter at the top.
function IronUi.box(parent: Instance, position: UDim2, size: UDim2, fill: Color3?, radius: number?): Frame
	local frame = new("Frame", { BackgroundColor3 = fill or P.Inset, Position = position, Size = size }, parent)
	UiKit.round(frame, radius or 12)
	new("UIStroke", {
		Color = P.Edge,
		Thickness = 1,
		Transparency = 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 196)),
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

-- A hover highlight for any button: a soft white glow washes over `surface`
-- (the button itself if none) and the outline turns gold. Eased in and out.
local HOVER_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function IronUi.highlight(button: GuiButton, surface: GuiObject?)
	local target = surface or button
	local glow, stroke
	local baseColor, baseThickness, baseTransparency
	local hovered, focused = false, false
	local tweens = {}
	local function transition()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
		local active = hovered or focused
		local function tween(object, properties)
			local effect = TweenService:Create(object, if active then HOVER_IN else HOVER_OUT, properties)
			table.insert(tweens, effect)
			effect:Play()
		end
		if glow and glow.Parent then
			tween(glow, { BackgroundTransparency = if active then 0.48 else 1 })
		end
		if stroke and stroke.Parent and baseColor then
			tween(stroke, {
				Color = if active then baseColor:Lerp(P.Gold, 0.38) else baseColor,
				Thickness = if active then math.max(baseThickness, 2) else baseThickness,
				Transparency = if active then 0.05 else baseTransparency,
			})
		end
	end
	local function capture()
		stroke = button:FindFirstChildOfClass("UIStroke") or target:FindFirstChildOfClass("UIStroke")
		if stroke then
			baseColor, baseThickness, baseTransparency = stroke.Color, stroke.Thickness, stroke.Transparency
		end
		if not glow and not target:FindFirstChildWhichIsA("UIGridStyleLayout") then
			glow = new("Frame", {
				Name = "HoverGlow",
				BackgroundColor3 = P.Teal,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = target.ZIndex + 3,
			}, target)
			local round = target:FindFirstChildOfClass("UICorner")
			if round then
				corner(glow, round.CornerRadius)
			end
			new("UIGradient", {
				Rotation = 115,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.6),
					NumberSequenceKeypoint.new(0.45, 0.92),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, glow)
		end
	end
	button.MouseEnter:Connect(function()
		if not hovered and not focused then
			capture()
		end
		hovered = true
		transition()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		transition()
	end)
	button.SelectionGained:Connect(function()
		if not hovered and not focused then
			capture()
		end
		focused = true
		transition()
	end)
	button.SelectionLost:Connect(function()
		focused = false
		transition()
	end)
end

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
-- Toy-bright colours are toned down to muted, weathered ones.
local function mute(color: Color3): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s * 0.8, math.min(v, 0.78))
end
IronUi.mute = mute

-- Keep the existing button/face contract so all menus share the new style.
function IronUi.chunk(parent: Instance, options: ChunkOptions): (TextButton, Frame)
	local fill = options.Color:Lerp(P.Inset, 0.16)
	local lip = math.clamp(options.Lip or 4, 2, 6)
	local radius = options.Radius or 8
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = darker(fill, 0.5),
		Size = options.Size or UDim2.fromOffset(120, 44),
	}, parent)
	corner(b, UDim.new(0, radius))
	new("UIStroke", {
		Color = options.Rim or options.Color:Lerp(P.Edge, 0.28),
		Thickness = 1.5,
		Transparency = 0.08,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	if (options.PadX or 0) > 0 then
		b:SetAttribute("PadX", options.PadX)
	end
	local rim = new("Frame", { Name = "Rim", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, b)
	local face = new(
		"Frame",
		{ Name = "Face", BackgroundColor3 = fill, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -lip) },
		rim
	)
	corner(face, UDim.new(0, math.max(2, radius - 1)))
	new("UIGradient", { Rotation = 95, Color = ColorSequence.new(lighter(fill, 0.28), darker(fill, 0.32)) }, face)
	new("Frame", {
		Name = "EdgeLight",
		BackgroundColor3 = options.Rim or options.Color,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(radius, 0),
		Size = UDim2.new(1, -radius * 2, 0, 1),
	}, face)
	if options.Stripes ~= "None" then
		new("Frame", {
			Name = "Accent",
			BackgroundColor3 = options.Rim or P.Teal,
			BackgroundTransparency = 0.3,
			Position = UDim2.fromOffset(0, radius),
			Size = UDim2.new(0, 2, 1, -radius * 2),
		}, face)
	end
	IronUi.juice(b, 1.035, 0.975)
	IronUi.highlight(b, face)
	return b, face
end

-- Text on the button face follows the button's own Text and
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

local SLATE = P.Slot

-- A chunky pill button: gold for the main action, slate for the rest.
function IronUi.button(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b, face = IronUi.chunk(parent, {
		Color = if primary then P.Teal else SLATE,
		Rim = if primary then P.Teal else P.Edge,
		Size = UDim2.fromOffset(0, 40),
		Radius = 10,
		Lip = 4,
		PadX = 16,
		Stripes = if primary then "Thin" else "None",
	})
	IronUi.label(b, face, label, 15)
	if primary then
		b:SetAttribute("UiSound", "Confirm")
	end
	b.Activated:Connect(onClick)
	return b
end

-- A prominent action button using the same restrained surface treatment.
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
	b:SetAttribute("UiSound", "Confirm")
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
		tab:SetAttribute("UiSound", "Tab")
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
	new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, badge)
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
	Dock: (number?) -> (),
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
	UiKit.round(panel, 8)
	-- A thin gold edge, and a dark iron body fading down.
	new("UIStroke", { Color = color:Lerp(P.Edge, 0.55), Thickness = 1.5 }, panel)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(30, 40, 62), P.Frame),
	}, panel)
	local rim = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
	}, panel)
	UiKit.round(rim, 12)
	new("UIStroke", { Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Thickness = 1.5, Transparency = 0.85 }, rim)

	-- Header bar.
	local header = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 0, 62),
	}, panel)
	UiKit.round(header, 6)
	-- A dark bar tinted with the window's colour, fading out to the right.
	local tint = mute(color)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, tint:Lerp(P.Inset, 0.32)),
			ColorSequenceKeypoint.new(1, P.Frame),
		}),
	}, header)
	-- A thin gold rule under the bar.
	new("Frame", {
		BackgroundColor3 = P.Edge,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
	}, header)

	local scale = new("UIScale", {}, panel)
	local target = 1
	local popping = false
	-- Docked: the panel sits on the right, using `dockShare` of the screen's
	-- width, and the backdrop isn't dimmed (a 3D scene shows beside it).
	local dockShare: number? = nil
	local function fit()
		local screen = gui.AbsoluteSize
		local wide = if dockShare then screen.X * dockShare else screen.X
		target = math.min(1, (wide - 40) / width, (screen.Y - 40) / height)
		if not popping then
			scale.Scale = target
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	-- Pop open (and fade the backdrop in) every time the window is shown.
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			UiSound.play("Close")
			return
		end
		UiSound.play("Open")
		fit()
		popping = true
		scale.Scale = target * 0.94
		shade.BackgroundTransparency = 1
		TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = if dockShare then 1 else 0.4 }):Play()
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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
		local badge = IronUi.badge(panel, icon, 38)
		badge.Position = UDim2.fromOffset(16, 14)
		badge.Rotation = 0
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
	local subtitle = IronUi.text(panel, "", 13, P.Dim, IronUi.Body)
	subtitle.Position = UDim2.fromOffset(left + 2, 44)
	subtitle.Size = UDim2.new(0.62, 0, 0, 16)
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle.AutomaticSize = Enum.AutomaticSize.None
	subtitle.ZIndex = 3

	-- A chunky red close button on the top-right corner.
	local close, closeFace = IronUi.chunk(panel, {
		Color = Color3.fromRGB(150, 60, 54),
		Size = UDim2.fromOffset(36, 36),
		Radius = 6,
		Lip = 3,
		Stripes = "None",
	})
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 18)
	close.ZIndex = 5
	close:SetAttribute("UiSound", "Back")
	IronUi.label(close, closeFace, "X", 18, IronUi.Chunky)

	-- Dock to the right with a share of the screen (e.g. 0.62), or nil to centre.
	local function dock(share: number?)
		dockShare = share
		if share then
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -20, 0.5, 0)
		else
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.fromScale(0.5, 0.5)
		end
		shade.BackgroundTransparency = if share then 1 else 0.4
		fit()
	end

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
		Dock = dock,
	}
end

return IronUi
