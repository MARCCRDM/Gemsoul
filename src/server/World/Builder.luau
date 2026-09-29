-- Shared building blocks for the retro-futuristic medieval style: weathered
-- stone, iron and wood, trimmed with neon, chrome and chunky CRT screens.
--
-- Every helper takes an `origin` CFrame (the zone's local space) and places
-- pieces relative to it, so each zone can be built facing the town plaza.
local CollectionService = game:GetService("CollectionService")

local Builder = {}

Builder.Colors = {
	Stone = Color3.fromRGB(158, 150, 138),
	WornStone = Color3.fromRGB(188, 178, 160),
	DarkStone = Color3.fromRGB(104, 98, 96),
	Obsidian = Color3.fromRGB(44, 38, 54),
	RoofBlue = Color3.fromRGB(46, 72, 128),
	Banner = Color3.fromRGB(38, 62, 140),
	Gold = Color3.fromRGB(230, 184, 70),
	Plaster = Color3.fromRGB(226, 214, 190),
	RoofRed = Color3.fromRGB(150, 70, 52),
	WindowGlass = Color3.fromRGB(80, 120, 160),
	Wood = Color3.fromRGB(104, 72, 46),
	DarkWood = Color3.fromRGB(66, 44, 30),
	Iron = Color3.fromRGB(58, 58, 64),
	Chrome = Color3.fromRGB(196, 202, 214),
	ScreenBg = Color3.fromRGB(6, 14, 10),

	Cyan = Color3.fromRGB(0, 240, 255),
	Magenta = Color3.fromRGB(255, 40, 190),
	Amber = Color3.fromRGB(255, 160, 30),
	Green = Color3.fromRGB(60, 255, 120),
	Purple = Color3.fromRGB(150, 70, 255),
	Red = Color3.fromRGB(255, 45, 70),
}
local C = Builder.Colors

-- A frame at `position` whose -Z (front) faces the direction (dx, dz).
function Builder.facing(position: Vector3, dx: number, dz: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, math.atan2(-dx, -dz), 0)
end

-- Offset in studs plus rotation in degrees.
function Builder.at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

function Builder.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

--[[
	props:
		Size (required), At (local CFrame), Name, Class ("Part", "WedgePart", ...),
		Shape, Color, Material, Transparency, CanCollide, CastShadow, Tag
]]
function Builder.part(parent: Instance, origin: CFrame, props: { [string]: any }): BasePart
	local part = Instance.new(props.Class or "Part")
	part.Name = props.Name or "Part"
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Size = props.Size
	part.CFrame = origin * (props.At or CFrame.identity)
	part.Color = props.Color or C.Stone
	part.Material = props.Material or Enum.Material.Slate
	part.Transparency = props.Transparency or 0
	part.CanCollide = props.CanCollide ~= false
	part.CastShadow = props.CastShadow ~= false
	if props.Tag then
		CollectionService:AddTag(part, props.Tag)
	end
	part.Parent = parent
	return part
end

-- A flat disc (Roblox cylinders lie along X, so this stands one upright).
function Builder.disc(parent: Instance, origin: CFrame, props: { [string]: any }): BasePart
	local at = props.At or CFrame.identity
	return Builder.part(parent, origin, {
		Name = props.Name or "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(props.Height or 1, props.Radius * 2, props.Radius * 2),
		At = at * CFrame.Angles(0, 0, math.rad(90)),
		Color = props.Color,
		Material = props.Material,
		Transparency = props.Transparency,
		CanCollide = props.CanCollide,
		CastShadow = props.CastShadow,
		Tag = props.Tag,
	})
end

function Builder.light(part: BasePart, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 2
	light.Shadows = false
	light.Parent = part
	return light
end

-- Glowing neon strip. Pass lightRange to also cast light.
function Builder.neon(
	parent: Instance,
	origin: CFrame,
	size: Vector3,
	at: CFrame,
	color: Color3,
	lightRange: number?,
	tag: string?
): BasePart
	local part = Builder.part(parent, origin, {
		Name = "Neon",
		Size = size,
		At = at,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Tag = tag,
	})
	if lightRange then
		Builder.light(part, color, lightRange)
	end
	return part
end

-- A ring of neon segments lying flat, centred on `center` (local space).
function Builder.neonRing(
	parent: Instance,
	origin: CFrame,
	center: Vector3,
	radius: number,
	count: number,
	color: Color3,
	width: number?
)
	local segment = 2 * math.pi * radius / count + 0.1
	for i = 0, count - 1 do
		local angle = i / count * 2 * math.pi
		Builder.neon(
			parent,
			origin,
			Vector3.new(segment, 0.2, width or 0.6),
			CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius),
			color
		)
	end
end

-- A glowing edge band: one neon cylinder slightly wider than the round part
-- it wraps, instead of a ring of separate segments.
function Builder.neonBand(parent: Instance, origin: CFrame, center: Vector3, radius: number, color: Color3)
	return Builder.disc(parent, origin, {
		Name = "NeonBand",
		Radius = radius + 0.15,
		Height = 0.3,
		At = CFrame.new(center),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
end

-- Battlements and a neon trim line along the top of a wall.
local function crown(parent: Instance, origin: CFrame, topCF: CFrame, length: number, props: { [string]: any })
	local thickness = props.Thickness or 2
	if props.Battlements then
		local spacing = 5
		local count = math.floor(length / spacing)
		for i = 0, count - 1 do
			local x = -count * spacing / 2 + spacing * i + spacing / 2
			Builder.part(parent, origin, {
				Name = "Merlon",
				Size = Vector3.new(2.5, 2.5, thickness),
				At = topCF * CFrame.new(x, 1.25, 0),
				Color = props.Color,
				Material = props.Material,
				CastShadow = false,
			})
		end
	end
	if props.Trim then
		for _, side in { -1, 1 } do
			Builder.neon(
				parent,
				origin,
				Vector3.new(length, 0.35, 0.12),
				topCF * CFrame.new(0, -1.2, side * (thickness / 2 + 0.06)),
				props.Trim
			)
		end
	end
end

local function wallFrame(x1: number, z1: number, x2: number, z2: number, baseY: number): (CFrame, number)
	local dx, dz = x2 - x1, z2 - z1
	local length = math.sqrt(dx * dx + dz * dz)
	local cf = CFrame.new((x1 + x2) / 2, baseY, (z1 + z2) / 2) * CFrame.Angles(0, math.atan2(-dz, dx), 0)
	return cf, length
end

local function segment(parent: Instance, origin: CFrame, baseCF: CFrame, length: number, height: number, props)
	return Builder.part(parent, origin, {
		Name = props.Name or "Wall",
		Size = Vector3.new(length, height, props.Thickness or 2),
		At = baseCF * CFrame.new(0, height / 2, 0),
		Color = props.Color,
		Material = props.Material or Enum.Material.Cobblestone,
	})
end

--[[
	A straight wall from (x1, z1) to (x2, z2) in local space.
	props: Thickness, BaseY, Color, Material, Battlements (bool), Trim (Color3)
]]
function Builder.wall(
	parent: Instance,
	origin: CFrame,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	height: number,
	props: { [string]: any }?
)
	local p = props or {}
	local baseCF, length = wallFrame(x1, z1, x2, z2, p.BaseY or 0)
	segment(parent, origin, baseCF, length, height, p)
	crown(parent, origin, baseCF * CFrame.new(0, height, 0), length, p)
end

-- Same as wall, with a doorway in the middle framed in neon (props.DoorTrim).
function Builder.wallWithDoor(
	parent: Instance,
	origin: CFrame,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	height: number,
	doorWidth: number,
	doorHeight: number,
	props: { [string]: any }?
)
	local p = props or {}
	local thickness = p.Thickness or 2
	local baseCF, length = wallFrame(x1, z1, x2, z2, p.BaseY or 0)
	local side = (length - doorWidth) / 2

	segment(parent, origin, baseCF * CFrame.new(-(doorWidth + side) / 2, 0, 0), side, height, p)
	segment(parent, origin, baseCF * CFrame.new((doorWidth + side) / 2, 0, 0), side, height, p)
	segment(parent, origin, baseCF * CFrame.new(0, doorHeight, 0), doorWidth, height - doorHeight, p)
	crown(parent, origin, baseCF * CFrame.new(0, height, 0), length, p)

	local trim = p.DoorTrim or p.Trim
	if trim then
		for _, sx in { -1, 1 } do
			Builder.neon(
				parent,
				origin,
				Vector3.new(0.4, doorHeight, thickness + 0.2),
				baseCF * CFrame.new(sx * doorWidth / 2, doorHeight / 2, 0),
				trim
			)
		end
		Builder.neon(
			parent,
			origin,
			Vector3.new(doorWidth + 0.4, 0.4, thickness + 0.2),
			baseCF * CFrame.new(0, doorHeight, 0),
			trim
		)
	end
end

-- Square stone column with a plinth, cap and glowing neon bands.
function Builder.pillar(
	parent: Instance,
	origin: CFrame,
	x: number,
	z: number,
	height: number,
	bandColor: Color3?,
	props: { [string]: any }?
)
	local p = props or {}
	local width = p.Width or 3
	local color = p.Color or C.WornStone
	local material = p.Material or Enum.Material.Cobblestone
	Builder.part(parent, origin, {
		Name = "Pillar",
		Size = Vector3.new(width, height, width),
		At = CFrame.new(x, height / 2, z),
		Color = color,
		Material = material,
	})
	for _, y in { 0.5, height - 0.5 } do
		Builder.part(parent, origin, {
			Name = "PillarTrim",
			Size = Vector3.new(width + 1, 1, width + 1),
			At = CFrame.new(x, y, z),
			Color = color,
			Material = material,
		})
	end
	if bandColor then
		for _, fraction in { 0.35, 0.7 } do
			Builder.neon(
				parent,
				origin,
				Vector3.new(width + 0.2, 0.35, width + 0.2),
				CFrame.new(x, height * fraction, z),
				bandColor
			)
		end
	end
end

-- Iron sconce holding a flickering neon crystal "flame".
function Builder.torch(parent: Instance, origin: CFrame, at: CFrame, color: Color3)
	Builder.part(parent, origin, {
		Name = "TorchBracket",
		Size = Vector3.new(0.6, 2, 0.6),
		At = at,
		Color = C.Iron,
		Material = Enum.Material.CorrodedMetal,
	})
	local flame = Builder.neon(
		parent,
		origin,
		Vector3.new(0.8, 0.8, 0.8),
		at * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color
	)
	CollectionService:AddTag(flame, "Flicker")
	return flame
end

-- Street lamp: stone base, iron post, chrome arm, neon lantern.
function Builder.lamp(parent: Instance, origin: CFrame, x: number, z: number, color: Color3, height: number?)
	local h = height or 12
	Builder.part(parent, origin, {
		Name = "LampBase",
		Size = Vector3.new(2, 1.5, 2),
		At = CFrame.new(x, 0.75, z),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.part(parent, origin, {
		Name = "LampPost",
		Size = Vector3.new(0.7, h, 0.7),
		At = CFrame.new(x, h / 2, z),
		Color = C.Iron,
		Material = Enum.Material.CorrodedMetal,
	})
	Builder.part(parent, origin, {
		Name = "LampCap",
		Size = Vector3.new(2.2, 0.4, 2.2),
		At = CFrame.new(x, h + 1.8, z),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	local lantern = Builder.neon(parent, origin, Vector3.new(1.4, 2.4, 1.4), CFrame.new(x, h + 0.4, z), color)
	CollectionService:AddTag(lantern, "Flicker")
end

local function addScanlines(frame: Frame, count: number)
	for i = 1, count do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.8
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Position = UDim2.fromScale(0, i / (count + 1))
		line.ZIndex = 3
		line.Parent = frame
	end
end

local function surfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font,
	background: Color3?,
	backgroundTransparency: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = background or C.ScreenBg
	frame.BackgroundTransparency = backgroundTransparency or 0
	frame.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Display"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = 2
	label.Parent = frame

	return label
end

--[[
	Chunky CRT monitor: a chrome box whose front (-Z) face glows with
	green-screen text. Returns the monitor part and its TextLabel ("Display").
	opts: Name, Text, TextColor, Tag, Font
]]
function Builder.screen(
	parent: Instance,
	origin: CFrame,
	at: CFrame,
	size: Vector3,
	opts: { [string]: any }?
): (BasePart, TextLabel)
	local o = opts or {}
	local monitor = Builder.part(parent, origin, {
		Name = o.Name or "CRT",
		Size = size,
		At = at,
		Color = C.Chrome,
		Material = Enum.Material.Metal,
		Tag = o.Tag,
	})
	-- Bulky tube housing behind the glass.
	Builder.part(parent, origin, {
		Name = "CRTHousing",
		Size = Vector3.new(size.X * 0.7, size.Y * 0.7, size.Z * 0.6),
		At = at * CFrame.new(0, 0, size.Z * 0.75),
		Color = C.Iron,
		Material = Enum.Material.Metal,
	})
	local label =
		surfaceText(monitor, Enum.NormalId.Front, o.Text or "", o.TextColor or C.Green, o.Font or Enum.Font.Code)
	addScanlines(label.Parent :: Frame, 12)
	return monitor, label
end

--[[
	Holographic panel: a thin glowing glass sheet with text on both faces.
	Returns the panel and its front TextLabel.
]]
function Builder.holo(
	parent: Instance,
	origin: CFrame,
	at: CFrame,
	size: Vector3,
	color: Color3,
	text: string,
	tag: string?
): (BasePart, TextLabel)
	local panel = Builder.part(parent, origin, {
		Name = "Hologram",
		Size = size,
		At = at,
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		CanCollide = false,
		CastShadow = false,
		Tag = tag,
	})
	local label = surfaceText(panel, Enum.NormalId.Front, text, Color3.new(1, 1, 1), Enum.Font.Arcade, color, 0.75)
	surfaceText(panel, Enum.NormalId.Back, text, Color3.new(1, 1, 1), Enum.Font.Arcade, color, 0.75)
	return panel, label
end

-- Iron plaque with glowing arcade-style lettering on its front (-Z) face.
function Builder.sign(parent: Instance, origin: CFrame, at: CFrame, size: Vector3, text: string, color: Color3)
	local plate = Builder.part(parent, origin, {
		Name = "Sign",
		Size = size,
		At = at,
		Color = C.Iron,
		Material = Enum.Material.DiamondPlate,
	})
	surfaceText(plate, Enum.NormalId.Front, text, color, Enum.Font.Arcade, Color3.fromRGB(10, 8, 16))
	-- Neon frame around the plaque.
	for _, sy in { -1, 1 } do
		Builder.neon(
			parent,
			origin,
			Vector3.new(size.X + 0.4, 0.25, 0.25),
			at * CFrame.new(0, sy * size.Y / 2, -size.Z / 2),
			color
		)
	end
	return plate
end

function Builder.prompt(part: BasePart, actionText: string, objectText: string, holdSeconds: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdSeconds or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

--[[
	Makes a part (a workbench, terminal...) talk for a shopkeeper: pressing
	[E] on it opens that shopkeeper's dialogue, and with `action` jumps
	straight to one of their options (see Dialogue.client).
]]
function Builder.station(part: BasePart, vendorId: string, actionText: string, objectText: string, action: string?)
	Builder.prompt(part, actionText, objectText)
	part:SetAttribute("VendorId", vendorId)
	if action then
		part:SetAttribute("VendorAction", action)
	end
end

-- Rugged, randomly tilted boulder.
function Builder.rock(parent: Instance, origin: CFrame, position: Vector3, size: Vector3, rng: Random)
	local shade = rng:NextNumber(0.8, 1.15)
	return Builder.part(parent, origin, {
		Name = "Rock",
		Size = size,
		At = CFrame.new(position) * CFrame.Angles(
			math.rad(rng:NextNumber(-8, 8)),
			math.rad(rng:NextNumber(0, 360)),
			math.rad(rng:NextNumber(-8, 8))
		),
		Color = Color3.new(C.DarkStone.R * shade, C.DarkStone.G * shade, C.DarkStone.B * shade),
		Material = Enum.Material.Rock,
	})
end

local LEAF_COLORS = {
	Color3.fromRGB(86, 150, 62),
	Color3.fromRGB(70, 132, 56),
	Color3.fromRGB(104, 160, 70),
	Color3.fromRGB(62, 118, 60),
}

local FLOWER_COLORS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 210, 80),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 60),
}

-- Leafy tree: a trunk and three rounded canopies. `position` is on the ground.
function Builder.tree(parent: Instance, position: Vector3, scale: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = 10 * scale
	Builder.part(model, CFrame.identity, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6 * scale, 1.6 * scale),
		At = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Wood,
		Material = Enum.Material.Wood,
	})
	local green = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local canopies = {
		{ Offset = Vector3.new(0, 1, 0), Size = 9 },
		{ Offset = Vector3.new(2.2, -1.5, 1), Size = 6.5 },
		{ Offset = Vector3.new(-2, -1, -1.6), Size = 6 },
	}
	for _, canopy in canopies do
		Builder.part(model, CFrame.identity, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * canopy.Size * scale,
			At = CFrame.new(position + Vector3.new(0, height, 0) + canopy.Offset * scale),
			Color = green,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	model.Parent = parent
	return model
end

-- Stone planter box full of flowers, running along the frame's X axis.
function Builder.planter(parent: Instance, origin: CFrame, at: CFrame, length: number, rng: Random)
	Builder.part(parent, origin, {
		Name = "Planter",
		Size = Vector3.new(length, 1.4, 3),
		At = at * CFrame.new(0, 0.7, 0),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.part(parent, origin, {
		Name = "Soil",
		Size = Vector3.new(length - 0.6, 0.2, 2.4),
		At = at * CFrame.new(0, 1.45, 0),
		Color = Color3.fromRGB(78, 56, 40),
		Material = Enum.Material.Ground,
		CastShadow = false,
	})
	local count = math.floor(length / 1.4)
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count
		Builder.part(parent, origin, {
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(0.8, 1.2),
			At = at * CFrame.new(x, 1.9, rng:NextNumber(-0.6, 0.6)),
			Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- Wooden bench; the seat faces the frame's -Z.
function Builder.bench(parent: Instance, origin: CFrame, at: CFrame)
	local wood = { Color = C.Wood, Material = Enum.Material.WoodPlanks }
	Builder.part(parent, origin, {
		Name = "BenchSeat",
		Size = Vector3.new(6, 0.5, 2),
		At = at * CFrame.new(0, 1.8, 0),
		Color = wood.Color,
		Material = wood.Material,
	})
	Builder.part(parent, origin, {
		Name = "BenchBack",
		Size = Vector3.new(6, 1.6, 0.4),
		At = at * CFrame.new(0, 3, 0.9) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = wood.Color,
		Material = wood.Material,
	})
	for _, x in { -2.4, 2.4 } do
		Builder.part(parent, origin, {
			Name = "BenchLeg",
			Size = Vector3.new(0.5, 1.6, 1.8),
			At = at * CFrame.new(x, 0.8, 0),
			Color = C.Iron,
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
	end
end

-- Hanging cloth banner with a gold stripe and a thin neon edge; faces -Z.
function Builder.banner(parent: Instance, origin: CFrame, at: CFrame, color: Color3, height: number)
	Builder.part(parent, origin, {
		Name = "BannerRod",
		Size = Vector3.new(6, 0.4, 0.4),
		At = at,
		Color = C.Iron,
		Material = Enum.Material.Metal,
		CastShadow = false,
	})
	Builder.part(parent, origin, {
		Name = "Banner",
		Size = Vector3.new(5, height, 0.2),
		At = at * CFrame.new(0, -height / 2, 0),
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
	Builder.part(parent, origin, {
		Name = "BannerStripe",
		Size = Vector3.new(1, height - 1, 0.1),
		At = at * CFrame.new(0, -height / 2, -0.12),
		Color = C.Gold,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
	Builder.neon(parent, origin, Vector3.new(5.1, 0.2, 0.25), at * CFrame.new(0, -height, 0), C.Cyan)
end

--[[
	Medieval house facing the frame's -Z: stone ground floor, an optional
	timber-framed plaster upper floor that juts out over the street, a pitched
	roof, door, windows and chimney. The front wall is at z = 0 and the house
	extends back to z = Depth. Returns the model.

	opts: Width, Depth, Floors (1 or 2), Stone, Upper, Roof, Trim, Name
]]
function Builder.house(parent: Instance, frame: CFrame, opts: { [string]: any }): Model
	local model = Instance.new("Model")
	model.Name = opts.Name or "House"
	local w, d = opts.Width, opts.Depth
	local floors = opts.Floors or 2
	local storey = 10

	Builder.part(model, frame, {
		Name = "GroundFloor",
		Size = Vector3.new(w, storey, d),
		At = CFrame.new(0, storey / 2, d / 2),
		Color = opts.Stone or C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	local top, front = storey, 0
	if floors >= 2 then
		front = -1.5
		local upper = storey - 1
		Builder.part(model, frame, {
			Name = "UpperFloor",
			Size = Vector3.new(w, upper, d - front),
			At = CFrame.new(0, storey + upper / 2, (d + front) / 2),
			Color = opts.Upper or C.Plaster,
			Material = Enum.Material.Plaster,
		})
		-- Timber framing on the jettied front.
		local beam = { Color = C.DarkWood, Material = Enum.Material.Wood, CastShadow = false }
		local z = front - 0.15
		for _, y in { storey + 0.3, storey + upper - 0.3 } do
			Builder.part(model, frame, {
				Name = "Beam",
				Size = Vector3.new(w, 0.6, 0.3),
				At = CFrame.new(0, y, z),
				Color = beam.Color,
				Material = beam.Material,
				CastShadow = false,
			})
		end
		for _, x in { -w / 2 + 0.3, 0, w / 2 - 0.3 } do
			Builder.part(model, frame, {
				Name = "Beam",
				Size = Vector3.new(0.6, upper, 0.3),
				At = CFrame.new(x, storey + upper / 2, z),
				Color = beam.Color,
				Material = beam.Material,
				CastShadow = false,
			})
		end
		top = storey + upper
		for _, x in { -w / 4, w / 4 } do
			Builder.part(model, frame, {
				Name = "Window",
				Size = Vector3.new(3, 3.4, 0.3),
				At = CFrame.new(x, storey + upper / 2, z - 0.05),
				Color = C.WindowGlass,
				Material = Enum.Material.Glass,
				CastShadow = false,
			})
		end
	end

	-- Pitched roof: two wedges meeting at a ridge that runs along the street.
	local roofDepth = d - front + 3
	local roofHeight = math.min(roofDepth * 0.4, 10)
	local roofFront = front - 1.5
	local roof = { Color = opts.Roof or C.RoofRed, Material = Enum.Material.Slate }
	Builder.part(model, frame, {
		Class = "WedgePart",
		Name = "Roof",
		Size = Vector3.new(w + 2, roofHeight, roofDepth / 2),
		At = CFrame.new(0, top + roofHeight / 2, roofFront + roofDepth / 4),
		Color = roof.Color,
		Material = roof.Material,
	})
	Builder.part(model, frame, {
		Class = "WedgePart",
		Name = "Roof",
		Size = Vector3.new(w + 2, roofHeight, roofDepth / 2),
		At = CFrame.new(0, top + roofHeight / 2, roofFront + roofDepth * 3 / 4) * CFrame.Angles(0, math.pi, 0),
		Color = roof.Color,
		Material = roof.Material,
	})
	Builder.part(model, frame, {
		Name = "Chimney",
		Size = Vector3.new(2.5, roofHeight + 4, 2.5),
		At = CFrame.new(w / 2 - 3, top + (roofHeight + 4) / 2, d * 0.65),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})

	-- Door and ground-floor windows.
	Builder.part(model, frame, {
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		At = CFrame.new(0, 3.5, -0.15),
		Color = C.DarkWood,
		Material = Enum.Material.WoodPlanks,
		CastShadow = false,
	})
	if w >= 16 then
		for _, x in { -w / 2 + 4, w / 2 - 4 } do
			Builder.part(model, frame, {
				Name = "Window",
				Size = Vector3.new(3, 3.4, 0.3),
				At = CFrame.new(x, 5, -0.1),
				Color = C.WindowGlass,
				Material = Enum.Material.Glass,
				CastShadow = false,
			})
		end
	end
	if opts.Trim then
		Builder.neon(model, frame, Vector3.new(w, 0.3, 0.2), CFrame.new(0, top - 0.6, front - 0.35), opts.Trim)
		Builder.neon(model, frame, Vector3.new(4.6, 0.3, 0.3), CFrame.new(0, 7.2, -0.35), opts.Trim)
	end

	model.Parent = parent
	return model
end

--[[
	A shopkeeper: a retro robot in a medieval tunic with a CRT monitor for a
	head. It stands at the frame's origin facing -Z. Talking to it opens the
	dialogue for `vendorId` (see Shared.Vendors).
]]
function Builder.vendor(parent: Instance, frame: CFrame, vendorId: string, info): Model
	local model = Instance.new("Model")
	model.Name = info.Name
	local limb = { Color = C.Chrome, Material = Enum.Material.Metal }

	for _, x in { -0.55, 0.55 } do
		Builder.part(model, frame, {
			Name = "Leg",
			Size = Vector3.new(0.9, 3, 0.9),
			At = CFrame.new(x, 1.5, 0),
			Color = C.Iron,
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
	end
	local torso = Builder.part(model, frame, {
		Name = "Torso",
		Size = Vector3.new(2.6, 3, 1.4),
		At = CFrame.new(0, 4.5, 0),
		Color = info.Tunic,
		Material = Enum.Material.Fabric,
	})
	Builder.neon(model, frame, Vector3.new(2.7, 0.3, 1.5), CFrame.new(0, 3.4, 0), info.Color)
	for _, x in { -1.75, 1.75 } do
		Builder.part(model, frame, {
			Name = "Arm",
			Size = Vector3.new(0.8, 2.8, 0.8),
			At = CFrame.new(x, 4.6, 0),
			Color = limb.Color,
			Material = limb.Material,
			CastShadow = false,
		})
	end
	local head = Builder.screen(model, frame, CFrame.new(0, 7.1, 0), Vector3.new(2.4, 2, 1.6), {
		Name = "Head",
		Text = info.Face,
		TextColor = info.Color,
	})
	Builder.part(model, frame, {
		Name = "Antenna",
		Size = Vector3.new(0.15, 1.2, 0.15),
		At = CFrame.new(0.7, 8.7, 0.3),
		Color = C.Iron,
		Material = Enum.Material.Metal,
		CastShadow = false,
	})
	Builder.neon(model, frame, Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.7, 9.4, 0.3), info.Color)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.Size = UDim2.fromOffset(220, 54)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = head
	for i, line in { { info.Name, Enum.Font.Arcade, info.Color }, { info.Role, Enum.Font.Code, Color3.new(1, 1, 1) } } do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.5)
		label.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		label.BackgroundTransparency = 1
		label.Text = line[1]
		label.Font = line[2]
		label.TextColor3 = line[3]
		label.TextStrokeTransparency = 0.4
		label.TextScaled = true
		label.Parent = billboard
	end

	local prompt = Builder.prompt(torso, "Talk", info.Name .. ", " .. info.Role)
	prompt.MaxActivationDistance = 10
	torso:SetAttribute("VendorId", vendorId)
	model.PrimaryPart = torso
	CollectionService:AddTag(model, "Vendor")
	model.Parent = parent
	return model
end

return Builder
