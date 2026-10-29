--[[
	A kaiju (or a boss) on show in a window, lit like a figure on a shelf:
	its element's colour washing up the back of the stage and glowing behind
	it, a lit disc under its feet, a soft rim of that colour round its
	outline so it stands off the dark, and a 3/4 view from a little below
	that fills the stage. A group (the Starter Rare Roll's four, the
	Triskull Trinity) stands together in one shot, the middle one forward.

	  Showcase.stage(parent, tint) -> Frame        the backdrop, filling parent
	  Showcase.model(stage, model, opts?) -> ViewportFrame
	  Showcase.group(stage, models, opts?) -> ViewportFrame
	      opts: Tint (the rim's colour), Halo (false: no rim), Spin (turns
	      slowly), Turn (the view's angle round it, radians), Fill (how
	      much of the stage it fills, 0-1), Aspect (the stage's width over
	      its height), Dark (a silhouette: locked)
	  Showcase.Light   the light every view is lit with
]]
local IronUi = require(script.Parent.IronUi)

local new = IronUi.new

local Showcase = {}

-- Bright, a little warm, from the front and above; enough ambient that the
-- dark side keeps its colours.
Showcase.Light = {
	Ambient = Color3.fromRGB(150, 156, 178),
	LightColor = Color3.fromRGB(255, 248, 236),
	LightDirection = Vector3.new(-0.45, -0.75, 0.5),
}
local NIGHT = Color3.fromRGB(9, 12, 22)

-- The backdrop: the element's colour rising from the floor into the dark,
-- a glow behind where it stands, the lit disc under it.
function Showcase.stage(parent: Instance, tint: Color3): Frame
	local stage = new("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, stage)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, NIGHT),
			ColorSequenceKeypoint.new(0.55, NIGHT:Lerp(tint, 0.22)),
			ColorSequenceKeypoint.new(1, NIGHT:Lerp(tint, 0.42)),
		}),
	}, stage)
	-- (the glow: many faint discs stacked, brightest at the middle, a
	-- radial light UIGradient can't do)
	for i = 1, 12 do
		local size = 1.3 - (i - 1) * 0.09
		local glow = new("Frame", {
			Name = "Glow" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(size, size),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = tint,
			BackgroundTransparency = 0.965,
		}, stage)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	end
	-- (the disc it stands on: lit at its middle, fading to its edges)
	local disc = new("Frame", {
		Name = "Disc",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.86, 0.16),
		BackgroundColor3 = tint:Lerp(Color3.new(1, 1, 1), 0.35),
		BackgroundTransparency = 0.55,
	}, stage)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, disc)
	-- (light catching the top edge)
	new("Frame", {
		Name = "Edge",
		BackgroundColor3 = tint:Lerp(Color3.new(1, 1, 1), 0.5),
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 1),
	}, stage)
	return stage
end

-- What's seen of a model: its parts' corners, in `frame`'s space (never a
-- see-through hitbox, which would shrink it to nothing).
local function bounds(models: { Model }, frame: CFrame): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, model in models do
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 0.95 then
				local half = part.Size / 2
				for _, c in
					{
						Vector3.new(-1, -1, -1),
						Vector3.new(-1, -1, 1),
						Vector3.new(-1, 1, -1),
						Vector3.new(-1, 1, 1),
						Vector3.new(1, -1, -1),
						Vector3.new(1, -1, 1),
						Vector3.new(1, 1, -1),
						Vector3.new(1, 1, 1),
					}
				do
					local p = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * c))
					lo, hi = lo:Min(p), hi:Max(p)
				end
			end
		end
	end
	return lo, hi
end

-- A view of `models` on the stage: the camera round the front at `turn`,
-- a little below their middle, far enough back that they fill `fill`.
local function view(stage: Frame, models: { Model }, opts): ViewportFrame
	opts = opts or {}
	local light = Showcase.Light
	local lo, hi = bounds(models, CFrame.new())
	local size = hi - lo
	local middle = (lo + hi) / 2
	-- (the floor: where the disc is)
	local aim = Vector3.new(middle.X, lo.Y + size.Y * 0.47, middle.Z)
	local turn = opts.Turn or 0.55
	local fov = 30
	local fill = opts.Fill or 0.84
	-- (far enough that it fits both ways: the stage's shape, `Aspect`, wide or tall)
	local aspect = opts.Aspect or 1
	local wide = math.max(size.X, size.Z) * 0.9
	local slope = math.tan(math.rad(fov / 2))
	local far = math.max((size.Y / 2) / slope, (wide / 2) / (slope * aspect)) / fill + math.max(size.X, size.Z) / 2
	local from = aim + Vector3.new(math.sin(turn), 0.16, -math.cos(turn)).Unit * far
	local function camera(parent: ViewportFrame)
		local cam = Instance.new("Camera")
		cam.FieldOfView = fov
		cam.CFrame = CFrame.lookAt(from, aim)
		cam.Parent = parent
		parent.CurrentCamera = cam
		return cam
	end
	local tint = opts.Tint or Color3.fromRGB(255, 196, 64)
	local cams = {}
	-- The rim: the same models a touch bigger behind, washed in the tint.
	if opts.Halo ~= false and not opts.Dark then
		local halo = new("ViewportFrame", {
			Name = "Halo",
			ZIndex = stage.ZIndex + 1,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.06, 1.06),
			Ambient = Color3.new(1, 1, 1),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = light.LightDirection,
			ImageColor3 = tint:Lerp(Color3.new(1, 1, 1), 0.25),
			ImageTransparency = 0.45,
		}, stage)
		for _, model in models do
			model:Clone().Parent = halo
		end
		table.insert(cams, camera(halo))
	end
	local main = new("ViewportFrame", {
		Name = "View",
		ZIndex = stage.ZIndex + 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = light.Ambient,
		LightColor = light.LightColor,
		LightDirection = light.LightDirection,
		-- (locked: a silhouette)
		ImageColor3 = if opts.Dark then Color3.fromRGB(10, 12, 20) else Color3.new(1, 1, 1),
	}, stage)
	for _, model in models do
		model.Parent = main
	end
	table.insert(cams, camera(main))
	-- Turning slowly: the cameras round it (the models stay put).
	if opts.Spin then
		local start = os.clock()
		IronUi.animate(main, function(t)
			local a = turn + (t - start) * 0.45
			local at = aim + Vector3.new(math.sin(a), 0.16, -math.cos(a)).Unit * far
			for _, cam in cams do
				cam.CFrame = CFrame.lookAt(at, aim)
			end
		end)
	end
	return main
end

function Showcase.model(stage: Frame, model: Model, opts): ViewportFrame
	return view(stage, { model }, opts)
end

-- A group in one shot: each scaled to one height, side by side, the middle
-- ones a step forward, all turned a little to the middle.
function Showcase.group(stage: Frame, models: { Model }, opts): ViewportFrame
	local n = #models
	local height = 6
	local widths = {}
	for i, model in models do
		local lo, hi = bounds({ model }, model:GetPivot())
		local size = hi - lo
		local scale = height / math.max(size.Y, 0.1)
		model:ScaleTo(model:GetScale() * scale)
		widths[i] = math.max(size.X, size.Z) * scale
	end
	local gap = 0.3
	local total = 0
	for _, w in widths do
		total += w * (1 - gap)
	end
	local x = -total / 2
	for i, model in models do
		local w = widths[i] * (1 - gap)
		local middle = (i - 1) / math.max(1, n - 1) - 0.5 -- -0.5 .. 0.5
		local forward = (0.5 - math.abs(middle)) * height * 0.5
		local spot = CFrame.new(x + w / 2, 0, -forward) * CFrame.Angles(0, middle * 0.6, 0)
		-- (its feet on the floor at its spot)
		local lo, hi = bounds({ model }, model:GetPivot())
		local feet = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
		model:PivotTo(spot * CFrame.new(-feet))
		x += w
	end
	return view(stage, models, opts)
end

return Showcase
