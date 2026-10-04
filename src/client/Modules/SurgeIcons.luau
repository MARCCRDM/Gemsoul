-- Resolution-independent surge symbols. Geometry avoids platform font fallback boxes.
local Icons = {}
-- Polylines in a unit square; every new surge has its own silhouette.
Icons.Paths =
	{
		["Cinder Drill"] = {
			{ { 0.18, 0.78 }, { 0.7, 0.26 }, { 0.84, 0.16 }, { 0.74, 0.45 }, { 0.22, 0.82 } },
			{ { 0.32, 0.55 }, { 0.48, 0.7 } },
			{ { 0.48, 0.39 }, { 0.64, 0.54 } },
		},
		["Furnace Crescent"] = {
			{ { 0.77, 0.15 }, { 0.39, 0.23 }, { 0.2, 0.48 }, { 0.34, 0.76 }, { 0.75, 0.85 }, { 0.53, 0.65 }, { 0.46, 0.45 }, {
				0.77,
				0.15,
			} },
			{ { 0.66, 0.36 }, { 0.84, 0.49 }, { 0.67, 0.63 } },
		},
		["Magma Fault"] = {
			{ { 0.12, 0.8 }, { 0.39, 0.62 }, { 0.3, 0.47 }, { 0.57, 0.31 }, { 0.5, 0.13 } },
			{ { 0.42, 0.83 }, { 0.63, 0.66 }, { 0.54, 0.52 }, { 0.79, 0.3 } },
			{ { 0.16, 0.36 }, { 0.24, 0.2 } },
			{ { 0.76, 0.78 }, { 0.86, 0.61 } },
		},
		["Solar Execution"] = {
			{ { 0.5, 0.13 }, { 0.61, 0.36 }, { 0.85, 0.5 }, { 0.61, 0.62 }, { 0.5, 0.87 }, { 0.39, 0.62 }, { 0.15, 0.5 }, {
				0.39,
				0.36,
			}, {
				0.5,
				0.13,
			} },
			{ { 0.5, 0.29 }, { 0.5, 0.7 } },
			{ { 0.33, 0.5 }, { 0.67, 0.5 } },
		},
		["Frost Needle"] = {
			{ { 0.2, 0.82 }, { 0.56, 0.24 }, { 0.81, 0.14 }, { 0.76, 0.4 }, { 0.2, 0.82 } },
			{ { 0.47, 0.52 }, { 0.31, 0.4 } },
			{ { 0.47, 0.52 }, { 0.63, 0.67 } },
		},
		["Glacier Fan"] = {
			{ { 0.5, 0.84 }, { 0.13, 0.43 }, { 0.26, 0.2 }, { 0.5, 0.84 }, { 0.5, 0.12 }, { 0.74, 0.2 }, { 0.5, 0.84 }, {
				0.87,
				0.43,
			} },
			{ { 0.15, 0.66 }, { 0.5, 0.88 }, { 0.85, 0.66 } },
		},
		["Permafrost Spire"] = {
			{ { 0.3, 0.84 }, { 0.3, 0.4 }, { 0.5, 0.12 }, { 0.7, 0.4 }, { 0.7, 0.84 }, { 0.3, 0.84 } },
			{ { 0.5, 0.12 }, { 0.5, 0.84 } },
			{ { 0.13, 0.8 }, { 0.13, 0.55 }, { 0.3, 0.65 } },
			{ { 0.7, 0.65 }, { 0.87, 0.55 }, { 0.87, 0.8 } },
		},
		["Shatter Crown"] = {
			{ { 0.17, 0.34 }, { 0.3, 0.51 }, { 0.5, 0.16 }, { 0.7, 0.51 }, { 0.83, 0.34 }, { 0.74, 0.8 }, { 0.26, 0.8 }, {
				0.17,
				0.34,
			} },
			{ { 0.28, 0.65 }, { 0.72, 0.65 } },
			{ { 0.47, 0.34 }, { 0.57, 0.52 }, { 0.43, 0.66 } },
		},
		["Caustic Dart"] = {
			{ { 0.18, 0.81 }, { 0.61, 0.38 }, { 0.55, 0.22 }, { 0.84, 0.16 }, { 0.78, 0.45 }, { 0.61, 0.38 } },
			{ { 0.21, 0.62 }, { 0.39, 0.8 } },
			{ { 0.39, 0.43 }, { 0.57, 0.61 } },
		},
		["Vitriol Sweep"] = {
			{ { 0.82, 0.18 }, { 0.35, 0.34 }, { 0.16, 0.62 }, { 0.25, 0.8 }, { 0.63, 0.74 }, { 0.83, 0.54 }, { 0.48, 0.63 }, {
				0.35,
				0.53,
			}, {
				0.82,
				0.18,
			} },
			{ { 0.61, 0.31 }, { 0.73, 0.41 } },
		},
		["Leech Bloom"] = {
			{
				{ 0.5, 0.5 },
				{ 0.3, 0.14 },
				{ 0.13, 0.35 },
				{ 0.5, 0.5 },
				{ 0.7, 0.14 },
				{ 0.87, 0.35 },
				{ 0.5, 0.5 },
				{ 0.84, 0.7 },
				{ 0.66, 0.88 },
				{ 0.5, 0.5 },
				{ 0.34, 0.88 },
				{ 0.16, 0.7 },
				{ 0.5, 0.5 },
			},
		},
		["Dissolution"] = {
			{ { 0.2, 0.2 }, { 0.8, 0.2 }, { 0.8, 0.44 } },
			{ { 0.2, 0.2 }, { 0.2, 0.65 }, { 0.39, 0.65 } },
			{ { 0.4, 0.38 }, { 0.66, 0.38 }, { 0.66, 0.64 }, { 0.4, 0.64 }, { 0.4, 0.38 } },
			{ { 0.32, 0.77 }, { 0.32, 0.86 } },
			{ { 0.56, 0.76 }, { 0.56, 0.88 } },
			{ { 0.8, 0.62 }, { 0.8, 0.75 } },
		},
		["Arc Needle"] = { { { 0.62, 0.12 }, { 0.26, 0.53 }, { 0.48, 0.53 }, { 0.38, 0.88 }, { 0.79, 0.42 }, { 0.56, 0.42 }, {
			0.62,
			0.12,
		} } },
		["Circuit Cleave"] = {
			{ { 0.17, 0.22 }, { 0.43, 0.22 }, { 0.43, 0.43 }, { 0.72, 0.43 }, { 0.83, 0.61 }, { 0.61, 0.81 }, { 0.2, 0.81 } },
			{ { 0.25, 0.4 }, { 0.25, 0.62 }, { 0.56, 0.62 } },
			{ { 0.62, 0.18 }, { 0.8, 0.18 }, { 0.8, 0.3 } },
		},
		["Thunder Pylon"] = {
			{ { 0.3, 0.85 }, { 0.7, 0.85 }, { 0.61, 0.6 }, { 0.61, 0.29 }, { 0.5, 0.13 }, { 0.39, 0.29 }, { 0.39, 0.6 }, {
				0.3,
				0.85,
			} },
			{ { 0.25, 0.32 }, { 0.13, 0.45 }, { 0.26, 0.51 }, { 0.15, 0.64 } },
			{ { 0.76, 0.32 }, { 0.87, 0.45 }, { 0.74, 0.51 }, { 0.85, 0.64 } },
		},
		["Railstorm"] = {
			{ { 0.18, 0.8 }, { 0.7, 0.28 } },
			{ { 0.3, 0.86 }, { 0.82, 0.34 } },
			{ { 0.16, 0.66 }, { 0.68, 0.14 } },
			{ { 0.52, 0.18 }, { 0.77, 0.18 }, { 0.77, 0.43 } },
			{ { 0.27, 0.42 }, { 0.5, 0.65 } },
		},
		["Resonant Reaver"] = {
			{ { 0.28, 0.14 }, { 0.16, 0.42 }, { 0.26, 0.73 }, { 0.5, 0.87 }, { 0.75, 0.69 }, { 0.63, 0.71 }, { 0.4, 0.6 }, {
				0.33,
				0.37,
			}, {
				0.28,
				0.14,
			} },
			{ { 0.54, 0.18 }, { 0.84, 0.48 }, { 0.54, 0.78 } },
			{ { 0.61, 0.37 }, { 0.72, 0.48 }, { 0.61, 0.59 } },
		},
		["Null Prism"] = {
			{ { 0.5, 0.12 }, { 0.83, 0.36 }, { 0.74, 0.77 }, { 0.36, 0.87 }, { 0.14, 0.54 }, { 0.5, 0.12 } },
			{ { 0.5, 0.12 }, { 0.5, 0.53 }, { 0.74, 0.77 } },
			{ { 0.14, 0.54 }, { 0.5, 0.53 }, { 0.83, 0.36 } },
			{ { 0.36, 0.87 }, { 0.5, 0.53 } },
		},
	}
function Icons.apply(label, definition, color)
	local name = if type(definition) == "table" then definition.Name else definition
	local paths = name and Icons.Paths[name]
	local old = label:FindFirstChild("SurgeSymbol")
	if not paths then
		if old then
			old:Destroy()
		end
		return
	end
	label.Text = ""
	if old and old:GetAttribute("Ability") == name then
		for _, part in old:GetChildren() do
			if part:IsA("Frame") then
				part.BackgroundColor3 = color
			end
		end
		return
	end
	if old then
		old:Destroy()
	end
	local canvas = Instance.new("Frame")
	canvas.Name = "SurgeSymbol"
	canvas:SetAttribute("Ability", name)
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(0.86, 0.86)
	canvas.ZIndex = label.ZIndex + 1
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.Parent = canvas
	for _, path in paths do
		for index = 2, #path do
			local a, b = path[index - 1], path[index]
			local dx, dy = b[1] - a[1], b[2] - a[2]
			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromScale((a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
			line.Size = UDim2.fromScale(math.sqrt(dx * dx + dy * dy) + 0.025, 0.047)
			line.Rotation = math.deg(math.atan2(dy, dx))
			line.BorderSizePixel = 0
			line.BackgroundColor3 = color
			line.ZIndex = canvas.ZIndex
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = line
			line.Parent = canvas
		end
	end
	canvas.Parent = label
end
return Icons
