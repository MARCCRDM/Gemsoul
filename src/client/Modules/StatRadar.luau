--[[
	A radar chart of a miner's build: one axis per stat, a web behind, the
	build's shape filled in front, each axis named with its value.

	Drawn with plain frames (lines are thin rotated frames; the fill is a
	fan of spokes from the centre to the shape's edge), built once and only
	moved afterwards. The shape eases to new values, so equipping a piece
	visibly grows or shrinks it.

	  StatRadar.create(parent, axes, radius) -> radar
	      axes = { { Name = "HEALTH", Color = Color3 }, ... } (clockwise from the top)
	  StatRadar.set(radar, values, texts)    values 0..1 per axis; texts shown by each name
	  StatRadar.step(radar, dt)              eases the shape; call every frame
]]
local StatRadar = {}

local IronUi = require(script.Parent.IronUi)

local RINGS = 4
local SPOKES = 120

local function make(class: string, props, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function line(frame: Frame, a: Vector2, b: Vector2, width: number)
	local delta = b - a
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(delta.Magnitude + width * 0.5, width)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local function bar(parent: Instance, color: Color3, transparency: number, z: number): Frame
	return make("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		ZIndex = z,
	}, parent)
end

function StatRadar.create(parent: GuiObject, axes, radius: number, fill: Color3)
	local count = #axes
	local size = radius * 2
	local chart = make("Frame", {
		Name = "StatRadar",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ZIndex = parent.ZIndex + 1,
	}, parent)
	local z = chart.ZIndex
	local centre = Vector2.new(radius, radius)
	local function point(i: number, r: number): Vector2
		local angle = -math.pi / 2 + (i - 1) / count * math.pi * 2
		return centre + Vector2.new(math.cos(angle), math.sin(angle)) * r
	end

	-- The web: rings and axes.
	local web = Color3.fromRGB(120, 150, 170)
	for ring = 1, RINGS do
		local r = radius * ring / RINGS
		for i = 1, count do
			line(bar(chart, web, if ring == RINGS then 0.55 else 0.8, z), point(i, r), point(i % count + 1, r), 1)
		end
	end
	for i = 1, count do
		line(bar(chart, web, 0.75, z), centre, point(i, radius), 1)
	end

	-- The shape: a fan of spokes for the fill, an outline, a dot per axis.
	local spokes = {}
	for s = 1, SPOKES do
		spokes[s] = bar(chart, fill, 0.72, z + 1)
	end
	local outline, dots = {}, {}
	for i = 1, count do
		outline[i] = bar(chart, fill:Lerp(Color3.new(1, 1, 1), 0.35), 0, z + 2)
		local dot = bar(chart, axes[i].Color, 0, z + 3)
		dot.Size = UDim2.fromOffset(6, 6)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.3 }, dot)
		dots[i] = dot
	end

	-- Names and values round the outside.
	local labels = {}
	for i, axis in axes do
		-- Side labels sit beside their point, reading away from the web, so a
		-- full stat's dot never lands under its own name.
		local tip = point(i, radius)
		local side = (tip - centre).X
		local align = if side > 4 then 0 elseif side < -4 then 1 else 0.5
		local at = if align == 0.5 then point(i, radius + 14) else tip + Vector2.new(if align == 0 then 8 else -8, 0)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(align, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(50, 24),
			ZIndex = z + 3,
		}, chart)
		local alignX = if align == 0 then Enum.TextXAlignment.Left elseif align == 1 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center
		local name = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 10),
			Text = axis.Name,
			TextSize = 9,
			Font = IronUi.Bold,
			TextColor3 = axis.Color,
			TextXAlignment = alignX,
			ZIndex = z + 3,
		}, holder)
		local value = make("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 14),
			Text = "",
			TextSize = 13,
			Font = IronUi.Heading,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = alignX,
			ZIndex = z + 3,
		}, holder)
		labels[i] = { Name = name, Value = value }
	end

	local radar = {
		Frame = chart,
		Count = count,
		Radius = radius,
		Point = point,
		Centre = centre,
		Spokes = spokes,
		Outline = outline,
		Dots = dots,
		Labels = labels,
		Current = table.create(count, 0),
		Target = table.create(count, 0),
		Dirty = true,
	}
	return radar
end

-- A value that just changed: its number flashes green or red and the
-- change floats up beside it.
function StatRadar.flash(radar, index: number, text: string, color: Color3)
	local label = radar.Labels[index]
	if not label then
		return
	end
	local TweenService = game:GetService("TweenService")
	label.Value.TextColor3 = color
	TweenService:Create(label.Value, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { TextColor3 = Color3.new(1, 1, 1) }):Play()
	local pop = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, -2),
		Size = UDim2.new(1, 0, 0, 12),
		Text = text,
		TextSize = 11,
		Font = IronUi.Heading,
		TextColor3 = color,
		TextXAlignment = label.Value.TextXAlignment,
		ZIndex = label.Value.ZIndex + 1,
	}, label.Value.Parent)
	TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(0, -16),
		TextTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		pop:Destroy()
	end)
end

function StatRadar.set(radar, values: { number }, texts: { string })
	for i = 1, radar.Count do
		radar.Target[i] = math.clamp(values[i] or 0, 0.04, 1)
		radar.Labels[i].Value.Text = texts[i] or ""
	end
	radar.Dirty = true
end

local function draw(radar)
	local count, radius, centre = radar.Count, radar.Radius, radar.Centre
	local corners = {}
	for i = 1, count do
		corners[i] = radar.Point(i, radius * radar.Current[i]) - centre
	end
	for i = 1, count do
		local a, b = corners[i], corners[i % count + 1]
		line(radar.Outline[i], centre + a, centre + b, 2)
		radar.Dots[i].Position = UDim2.fromOffset(centre.X + a.X, centre.Y + a.Y)
	end
	-- Each spoke runs from the centre to where its ray meets the outline.
	for s, spoke in radar.Spokes do
		local angle = -math.pi / 2 + (s - 0.5) / #radar.Spokes * math.pi * 2
		local direction = Vector2.new(math.cos(angle), math.sin(angle))
		local sector = math.floor(((angle + math.pi / 2) / (math.pi * 2)) * count) % count + 1
		local p, q = corners[sector], corners[sector % count + 1]
		local edge = q - p
		local across = direction.X * edge.Y - direction.Y * edge.X
		local reach = if math.abs(across) > 1e-6 then (p.X * edge.Y - p.Y * edge.X) / across else 0
		line(spoke, centre, centre + direction * math.max(reach, 0), 3)
	end
end

function StatRadar.step(radar, dt: number)
	local moving = radar.Dirty
	local ease = 1 - math.exp(-8 * dt)
	for i = 1, radar.Count do
		local gap = radar.Target[i] - radar.Current[i]
		if math.abs(gap) > 0.002 then
			radar.Current[i] += gap * ease
			moving = true
		elseif gap ~= 0 then
			radar.Current[i] = radar.Target[i]
			moving = true
		end
	end
	if moving then
		radar.Dirty = false
		draw(radar)
	end
end

return StatRadar
