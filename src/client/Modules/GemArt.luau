--[[
	Turns GemShapes into real 3D models for ViewportFrames.

	GemArt.model(gem, detailed)      a Model of the stone centred on the
	                                 origin, and its bounding radius
	GemArt.pose(gem, spin)           how to hold it: cut stones tilt their
	                                 table toward the camera
	GemArt.setupViewport(frame, d)   bright studio lighting, camera at d
	GemArt.cardDistance(radius)      camera distance for cards: stones fill
	                                 the card, bigger ones a bit more
	GemArt.detailDistance(radius)    camera distance for the close-up
	GemArt.backdrop(parent)          neutral spotlight and floor shadow, so
	                                 any colour of stone stands out
	GemArt.viewport(parent, gem)     a ready-made static view, for cards
]]
local GemShapes = require(script.Parent.GemShapes)

local GemArt = {}

local FACET_THICKNESS = 0.02
local CAMERA_FOV = 34

local function wedge(model: Model, spec, color: Color3, transparency: number)
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Glass
	part.Color = color
	part.Transparency = transparency
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Parent = model
end

local function ball(
	model: Model,
	position: Vector3,
	radius: number,
	color: Color3,
	transparency: number,
	neon: boolean?
)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.one * radius * 2
	part.CFrame = CFrame.new(position)
	part.Parent = model
end

function GemArt.model(gem, detailed: boolean?): (Model, number)
	local shape = GemShapes.build(gem, detailed)
	local model = Instance.new("Model")
	model.Name = "Gem"
	for _, triangle in shape.Triangles do
		-- Skip slivers too thin to draw.
		if (triangle.B - triangle.A):Cross(triangle.C - triangle.A).Magnitude > 1e-5 then
			local first, second = GemShapes.wedges(triangle.A, triangle.B, triangle.C, FACET_THICKNESS)
			wedge(model, first, triangle.Color, shape.Transparency)
			wedge(model, second, triangle.Color, shape.Transparency)
		end
	end
	for _, speck in shape.Specks do
		ball(model, speck.Position, speck.Radius, speck.Color, speck.Transparency, speck.Glow)
	end
	for _, point in shape.Sparkles do
		ball(model, point, 0.06, Color3.new(1, 1, 1), 0, true)
	end
	model.WorldPivot = CFrame.new()
	return model, shape.Radius
end

-- Cards: every stone fills most of the card, but a size-10 stone still
-- looks noticeably bigger than a size-1.
function GemArt.cardDistance(radius: number): number
	return (radius + (GemShapes.MaxRadius - radius) * 0.3) * 2.7
end

function GemArt.detailDistance(radius: number): number
	return radius * 2.8
end

-- A soft grey spotlight with a shadow beneath the stone. Neutral on
-- purpose: a stone never sits on a background of its own colour.
function GemArt.backdrop(parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Backdrop"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 1
	holder.Parent = parent

	local spot = Instance.new("Frame")
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.fromScale(0.5, 0.46)
	spot.Size = UDim2.fromScale(0.92, 0.92)
	spot.BackgroundColor3 = Color3.fromRGB(190, 200, 215)
	spot.BorderSizePixel = 0
	spot.Parent = holder
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = spot
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = spot
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.55, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = spot

	local shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.84)
	shadow.Size = UDim2.fromScale(0.55, 0.09)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.Parent = holder
	local shadowRound = Instance.new("UICorner")
	shadowRound.CornerRadius = UDim.new(0.5, 0)
	shadowRound.Parent = shadow
	return holder
end

function GemArt.pose(gem, spin: number): CFrame
	local tilt = if gem.Cut then -28 else -12
	return CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.Angles(0, spin, 0)
end

function GemArt.setupViewport(viewport: ViewportFrame, distance: number?): Camera
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	local camera = viewport:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = viewport
	end
	viewport.CurrentCamera = camera
	camera.FieldOfView = CAMERA_FOV
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance or GemShapes.MaxRadius * 3.5), Vector3.zero)
	return camera
end

-- A static 3D view of the gem filling `parent`.
function GemArt.viewport(parent: Instance, gem, detailed: boolean?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	-- Square and centred, so the stone sits inside the round backdrop.
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = 2
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = viewport
	local model, radius = GemArt.model(gem, detailed)
	GemArt.setupViewport(viewport, GemArt.cardDistance(radius))
	model:PivotTo(GemArt.pose(gem, 0.6))
	model.Parent = viewport
	viewport.Parent = parent
	return viewport
end

-- Close-up inspector with explicit controls; no perpetual animation or global
-- input connections. Keep the whole stone inside the camera at every angle.
function GemArt.inspectorViewport(parent: Instance, gem, angles)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "GemInspectorViewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = 2
	local model, radius = GemArt.model(gem, true)
	local camera = GemArt.setupViewport(viewport)
	model.Parent = viewport
	viewport.Parent = parent
	local function fitCamera()
		local size = viewport.AbsoluteSize
		local aspect = if size.Y > 0 then math.max(size.X / size.Y, 0.1) else 1
		local halfFov = math.rad(CAMERA_FOV / 2)
		local limitingFov = math.min(halfFov, math.atan(math.tan(halfFov) * aspect))
		local distance = radius / math.sin(limitingFov) * 1.12
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	end
	local function pose()
		model:PivotTo(CFrame.Angles(math.rad(angles.Tilt), 0, 0) * GemArt.pose(gem, angles.Spin))
	end
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
	fitCamera()
	pose()
	return viewport,
		{
			Rotate = function(delta: number)
				angles.Spin = (angles.Spin + delta) % (math.pi * 2)
				pose()
			end,
			Tilt = function()
				angles.Tilt = if angles.Tilt == 0 then -35 elseif angles.Tilt == -35 then 25 else 0
				pose()
			end,
			Reset = function()
				angles.Spin, angles.Tilt = 0.6, 0
				pose()
			end,
		}
end

return GemArt
