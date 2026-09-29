--[[
	Pictures of gems, all real 3D models so the pouch, the picker and the
	detail view show the same stone.

	GemArt.model(gem): a 3D model centred on (0, 1.3, 0), for a ViewportFrame.
	GemArt.icon(parent, gem, size): a square card icon (a ViewportFrame of
	the same model, seen from a fixed camera, so bigger stones look bigger).

	Rough stones look like real rough gem pebbles: rounded, water-worn lumps
	with a few chipped flat faces. Cut stones are a round brilliant: flat
	table, faceted crown, thin girdle and a pointed pavilion.

	What each property does to the look:
	  Colour tier  the shade's colour (two-tone for Fusion, rainbow facets for Prismatic)
	  Size 1-10    how big the stone is (0.7x to 1.3x)
	  Clarity 1-10 milky and opaque with dark inclusions at 1, glassy and
	               see-through with a glowing heart at 7+
	  Cut 1-10     rough pebble while uncut; once cut, low grades are lopsided
	               and dull, high grades symmetric with bright facets, and
	               Gem Mint (10) twinkles
	Every stone's shape comes from its id, so no two rough stones match.
]]
local GemConfig = require(game:GetService("ReplicatedStorage").Shared.GemConfig)

local GemArt = {}

local CENTER = Vector3.new(0, 1.3, 0)
local TWO_PI = math.pi * 2
local MILK = Color3.fromRGB(226, 226, 220) -- what cloudy stones blur toward
local INCLUSION = Color3.fromRGB(40, 36, 34)
local FACETS = 16 -- sides of the round brilliant

-- Round brilliant proportions, as fractions of the diameter.
local TABLE = 0.56
local CROWN = 0.16
local PAVILION = 0.43
local GIRDLE = 0.03

-- A stable number from a gem id, so its random shape never changes.
local function seedOf(gem): number
	local seed = 7
	for i = 1, #gem.Id do
		seed = (seed * 31 + string.byte(gem.Id, i)) % 2147483647
	end
	return seed
end

local function lighter(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s * (1 - amount * 0.6), math.min(1, v + amount))
end

local function darker(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * (1 - amount))
end

-- 0 at grade 1, 1 at grade 10.
local function grade(value: number?): number
	return (math.clamp(value or 1, 1, 10) - 1) / 9
end

local function sizeScale(gem): number
	return 0.7 + grade(gem.Size) * 0.6
end

-- The colour of the i-th of n pieces: plain, two-tone (Fusion) or a rainbow (Prismatic).
local function pieceColor(shade, i: number, n: number): Color3
	if shade.Prismatic then
		local h = ((i - 1) / n + 0.3) % 1
		return shade.Color:Lerp(Color3.fromHSV(h, 0.75, 1), 0.55)
	elseif shade.Color2 and i % 2 == 0 then
		return shade.Color2
	end
	return shade.Color
end

----------------------------------------------------------------------------------
-- WedgePart orientation: measured once instead of assumed, so the facets can't
-- come out inside-out. A probe wedge far above the map is raycast from above
-- at both ends; the end the ray hits higher is the tall one.
----------------------------------------------------------------------------------

local tallSign: number? = nil -- +1: a WedgePart is full height at its local +Z end

local function wedgeTallSign(): number
	if tallSign then
		return tallSign
	end
	tallSign = 1
	pcall(function()
		local probe = Instance.new("WedgePart")
		probe.Anchored = true
		probe.CanCollide = false
		probe.Transparency = 1
		probe.Size = Vector3.new(4, 4, 4)
		probe.CFrame = CFrame.new(0, 20000, 0)
		probe.Parent = workspace
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { probe }
		local function heightAt(z: number): number
			local hit = workspace:Raycast(Vector3.new(0, 20004, z), Vector3.new(0, -8, 0), params)
			return if hit then hit.Position.Y else -math.huge
		end
		local plus, minus = heightAt(1.6), heightAt(-1.6)
		probe:Destroy()
		if minus > plus then
			tallSign = -1
		end
	end)
	return tallSign :: number
end

----------------------------------------------------------------------------------
-- Parts
----------------------------------------------------------------------------------

local function part(
	model: Model,
	className: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	props: { [string]: any }?
): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Glass
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	for key, value in props or {} do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

-- An ellipsoid (a Part with a sphere mesh stretched to its size).
local function blob(model: Model, size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?): BasePart
	local p = part(model, "Part", size, cframe, color, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

----------------------------------------------------------------------------------
-- Rough stone: a water-worn pebble
----------------------------------------------------------------------------------

local function roughModel(model: Model, gem, shade)
	local rng = Random.new(seedOf(gem))
	local s = sizeScale(gem)
	local clarity = grade(gem.Clarity)

	-- Cloudy stones are milky and nearly opaque; clear ones are glassy.
	local milk = 0.4 * (1 - clarity)
	local look = { Transparency = 0.04 + clarity * 0.32, Reflectance = 0.05 + clarity * 0.1 }
	local pieces = 5

	local function randomTurn(): CFrame
		return CFrame.Angles(rng:NextNumber(0, TWO_PI), rng:NextNumber(0, TWO_PI), rng:NextNumber(0, TWO_PI))
	end

	-- Body: a chunky main lump plus two smaller lumps, all rounded.
	local main = Vector3.new(rng:NextNumber(1.9, 2.2), rng:NextNumber(1.5, 1.8), rng:NextNumber(1.5, 1.8)) * s
	local mainFrame = CFrame.new(CENTER)
		* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TWO_PI), rng:NextNumber(-0.3, 0.3))
	blob(model, main, mainFrame, pieceColor(shade, 1, pieces):Lerp(MILK, milk), look)
	for i = 2, 3 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-1, 1)).Unit
		local lobe = main * Vector3.new(rng:NextNumber(0.5, 0.7), rng:NextNumber(0.55, 0.75), rng:NextNumber(0.5, 0.7))
		blob(
			model,
			lobe,
			CFrame.new(CENTER + direction * main.X * 0.26) * randomTurn(),
			lighter(pieceColor(shade, i, pieces), 0.04 * (i - 1)):Lerp(MILK, milk),
			look
		)
	end

	-- Chipped faces: two boxes, turned only a little from the main lump, whose
	-- faces just break through the rounded surface as flat fractures, like the
	-- broken sides of real rough stones.
	for i = 4, 5 do
		local chip = main
			* Vector3.new(rng:NextNumber(0.6, 0.68), rng:NextNumber(0.58, 0.66), rng:NextNumber(0.6, 0.68))
		local offset = Vector3.new(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.1, 0.1))
		local tilt = CFrame.Angles(rng:NextNumber(-0.45, 0.45), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.45, 0.45))
		part(
			model,
			"Part",
			chip,
			mainFrame * CFrame.new(offset * s) * tilt,
			darker(pieceColor(shade, i, pieces), 0.08):Lerp(MILK, milk),
			look
		)
	end

	-- Inclusions: dark flecks near the surface of low-clarity stones.
	local flecks = math.floor((1 - clarity) * 4 + 0.5)
	for _ = 1, flecks do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 0.9), rng:NextNumber(-1, 1)).Unit
		local radius = rng:NextNumber(0.1, 0.16) * s
		blob(
			model,
			Vector3.new(radius * 2, radius, radius * 2),
			CFrame.new(CENTER + direction * main * 0.47) * randomTurn(),
			INCLUSION,
			{ Material = Enum.Material.SmoothPlastic, Transparency = 0.15 }
		)
	end

	-- A glowing heart that shows through clear stones.
	if gem.Clarity >= 7 then
		blob(
			model,
			main * 0.42,
			CFrame.new(CENTER),
			lighter(shade.Color2 or shade.Color, 0.35),
			{ Material = Enum.Material.Neon, Transparency = 0.55 - clarity * 0.3 }
		)
	end
end

----------------------------------------------------------------------------------
-- Cut stone: a round brilliant
----------------------------------------------------------------------------------

local function cutModel(model: Model, gem, shade)
	local rng = Random.new(seedOf(gem))
	local s = sizeScale(gem)
	local clarity = grade(gem.Clarity)
	local cut = grade(gem.Cut)
	local sign = wedgeTallSign()

	local diameter = 2.4 * s
	local radius = diameter / 2
	local apothem = radius * math.cos(math.pi / FACETS)
	local facetWidth = 2 * radius * math.sin(math.pi / FACETS)
	local tableRadius = radius * TABLE
	local crown = diameter * CROWN
	local pavilion = diameter * PAVILION
	local girdle = diameter * GIRDLE
	-- Centre the whole stone (culet to table) on CENTER.
	local girdleY = CENTER.Y + (pavilion - crown) / 2

	-- A poor cut is lopsided: facet heights wander. Grades 9-10 are exact.
	local wobble = if (gem.Cut or 0) >= 9 then 0 else (1 - cut) * 0.3
	-- A good cut throws more light: facets alternate brighter and darker.
	local sparkle = 0.08 + cut * 0.22
	local milk = 0.25 * (1 - clarity)
	local transparency = 0.1 + clarity * 0.35
	local look = { Transparency = transparency, Reflectance = 0.1 + cut * 0.25 }
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- stands a cylinder on its end
	local upsideDown = CFrame.Angles(0, 0, math.pi)

	local function facetColor(i: number, bright: number): Color3
		local color = pieceColor(shade, i, FACETS):Lerp(MILK, milk)
		return if i % 2 == 0 then lighter(color, sparkle * bright) else darker(color, sparkle * 0.7)
	end

	-- Girdle and table.
	part(
		model,
		"Part",
		Vector3.new(girdle, apothem * 2, apothem * 2),
		CFrame.new(0, girdleY, 0) * upright,
		shade.Color:Lerp(MILK, milk),
		{ Shape = Enum.PartType.Cylinder, Transparency = transparency }
	)
	part(
		model,
		"Part",
		Vector3.new(crown, tableRadius * 2, tableRadius * 2),
		CFrame.new(0, girdleY + girdle / 2 + crown / 2, 0) * upright,
		lighter(shade.Color, 0.15):Lerp(MILK, milk),
		{ Shape = Enum.PartType.Cylinder, Transparency = transparency, Reflectance = look.Reflectance }
	)

	for i = 1, FACETS do
		local angle = (i - 0.5) / FACETS * TWO_PI
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))

		-- Crown facet: full height at the table's edge, sloping down to the girdle.
		local crownHeight = crown * (1 + rng:NextNumber(-wobble, wobble))
		local crownDepth = apothem - tableRadius
		local crownPos = Vector3.new(0, girdleY + girdle / 2 + crownHeight / 2, 0)
			+ outward * (tableRadius + crownDepth / 2)
		part(
			model,
			"WedgePart",
			Vector3.new(facetWidth, crownHeight, crownDepth),
			CFrame.lookAt(crownPos, crownPos + outward * sign),
			facetColor(i, 1),
			look
		)

		-- Pavilion facet: upside down, deepest at the centre (the culet).
		local pavilionDepth = pavilion * (1 + rng:NextNumber(-wobble, wobble))
		local pavilionPos = Vector3.new(0, girdleY - girdle / 2 - pavilionDepth / 2, 0) + outward * (apothem / 2)
		part(
			model,
			"WedgePart",
			Vector3.new(facetWidth, pavilionDepth, apothem),
			CFrame.lookAt(pavilionPos, pavilionPos + outward * sign) * upsideDown,
			facetColor(i + 1, 0.6),
			look
		)
	end

	-- A glowing heart in clear stones.
	if gem.Clarity >= 7 then
		blob(
			model,
			Vector3.new(radius * 0.7, pavilion * 0.35, radius * 0.7),
			CFrame.new(0, girdleY - pavilion * 0.2, 0),
			lighter(shade.Color2 or shade.Color, 0.35),
			{ Material = Enum.Material.Neon, Transparency = 0.55 - clarity * 0.3 }
		)
	end

	-- Gem Mint: a four-point twinkle on the table.
	if (gem.Cut or 0) >= 10 then
		local twinkle = CFrame.new(radius * 0.3, girdleY + girdle / 2 + crown + 0.05, -radius * 0.2)
		for _, spin in { 0, math.pi / 2 } do
			part(
				model,
				"Part",
				Vector3.new(radius * 0.9, 0.04, 0.04),
				twinkle * CFrame.Angles(0, spin, 0),
				Color3.new(1, 1, 1),
				{ Material = Enum.Material.Neon }
			)
		end
	end
end

--[[
	A 3D model of the gem centred on (0, 1.3, 0), with WorldPivot at the
	origin so callers can spin it with PivotTo(CFrame.Angles(0, t, 0)).
]]
function GemArt.model(gem): Model
	local shade = GemConfig.shade(gem)
	local model = Instance.new("Model")
	model.Name = if gem.Cut then "CutGem" else "RoughStone"
	if gem.Cut then
		cutModel(model, gem, shade)
	else
		roughModel(model, gem, shade)
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Icon camera: fixed, so a size-10 stone fills the icon and a size-1 stone is visibly smaller.
local ICON_FOV = 30
local ICON_DISTANCE = 7.4
local ICON_ELEVATION = math.rad(24)

-- A square gem icon filling `size` pixels (or scale 1 if size is nil).
function GemArt.icon(parent: Instance, gem, size: number?): Frame
	local shade = GemConfig.shade(gem)
	local holder = Instance.new("Frame")
	holder.Name = "GemIcon"
	holder.BackgroundTransparency = 1
	holder.Size = if size then UDim2.fromOffset(size, size) else UDim2.fromScale(1, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = holder

	-- Soft glow behind the stone.
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.95, 0.95)
	glow.BorderSizePixel = 0
	glow.BackgroundColor3 = if shade.Prismatic then Color3.fromRGB(200, 120, 255) else shade.Color
	glow.BackgroundTransparency = 0.8
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = glow
	glow.Parent = holder

	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(150, 150, 165)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-0.5, -1, -0.7)
	local camera = Instance.new("Camera")
	camera.FieldOfView = ICON_FOV
	local eye = CENTER + Vector3.new(0, math.sin(ICON_ELEVATION), math.cos(ICON_ELEVATION)) * ICON_DISTANCE
	camera.CFrame = CFrame.lookAt(eye, CENTER)
	camera.Parent = view
	view.CurrentCamera = camera

	local model = GemArt.model(gem)
	model:PivotTo(CFrame.Angles(0, Random.new(seedOf(gem)):NextNumber(0, TWO_PI), 0))
	model.Parent = view
	view.Parent = holder

	holder.Parent = parent
	return holder
end

return GemArt
