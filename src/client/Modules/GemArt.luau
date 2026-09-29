--[[
	Turns GemShapes into real 3D models for ViewportFrames.

	GemArt.model(gem, detailed)   a Model of the stone, centred on the origin
	GemArt.pose(gem, spin)        how to hold it: cut stones tilt their table
	                              toward the camera; `spin` turns it around
	GemArt.setupViewport(frame)   lighting and a fixed camera, so bigger
	                              stones really do look bigger
	GemArt.viewport(parent, gem)  a ready-made static view, for cards
]]
local GemShapes = require(script.Parent.GemShapes)

local GemArt = {}

local FACET_THICKNESS = 0.02
local CAMERA_FOV = 34
local CAMERA_DISTANCE = GemShapes.MaxRadius * 3.5

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

function GemArt.model(gem, detailed: boolean?): Model
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
		ball(model, speck.Position, speck.Radius, speck.Color, speck.Transparency)
	end
	for _, point in shape.Sparkles do
		ball(model, point, 0.06, Color3.new(1, 1, 1), 0, true)
	end
	model.WorldPivot = CFrame.new()
	return model
end

function GemArt.pose(gem, spin: number): CFrame
	local tilt = if gem.Cut then -28 else -12
	return CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.Angles(0, spin, 0)
end

function GemArt.setupViewport(viewport: ViewportFrame): Camera
	viewport.Ambient = Color3.fromRGB(150, 150, 165)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.7)
	local camera = viewport:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = viewport
	end
	viewport.CurrentCamera = camera
	camera.FieldOfView = CAMERA_FOV
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, CAMERA_DISTANCE), Vector3.zero)
	return camera
end

-- A static 3D view of the gem filling `parent`.
function GemArt.viewport(parent: Instance, gem, detailed: boolean?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	GemArt.setupViewport(viewport)
	local model = GemArt.model(gem, detailed)
	model:PivotTo(GemArt.pose(gem, 0.6))
	model.Parent = viewport
	viewport.Parent = parent
	return viewport
end

return GemArt
