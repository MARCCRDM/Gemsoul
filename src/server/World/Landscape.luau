-- Terrain around the town: a grassy plain, the moat, rolling hills,
-- a ring of snow-capped mountains on the horizon, a dirt road leading out
-- of the main gate, and trees scattered across the countryside.
local Builder = require(script.Parent.Builder)
local Hub = require(script.Parent.Hub)

local Terrain = workspace.Terrain

local PLAIN_SIZE = 2200 -- also covers the default Baseplate
local GROUND_TOP = 0.5
local MOAT_WIDTH = 22
local ROAD_LENGTH = 420

local Landscape = {}

-- Repaints the ground surface inside a flat rectangle (centre, size in X/Z)
-- with another terrain material, keeping the ground level unchanged.
function Landscape.paint(center: Vector3, sizeX: number, sizeZ: number, material: Enum.Material)
	Terrain:FillBlock(CFrame.new(center.X, GROUND_TOP - 2, center.Z), Vector3.new(sizeX, 4, sizeZ), material)
end

local function angleFrom(angle: number, target: number): number
	local diff = math.abs(angle - target) % 360
	return math.min(diff, 360 - diff)
end

local function styleTerrain()
	Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 160, 72))
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 122, 118))
	Terrain.WaterColor = Color3.fromRGB(58, 140, 170)
	Terrain.WaterTransparency = 0.6
	Terrain.WaterReflectance = 0.5
	Terrain.WaterWaveSize = 0.08
	Terrain.WaterWaveSpeed = 6
end

local function moat(moatDistance: number, sides: number)
	-- One straight trench per wall side; overlapping ends close the corners.
	local length = 2 * moatDistance * math.tan(math.pi / sides) + 10
	for k = 1, sides do
		local frame = Hub.radial(k * 360 / sides) * CFrame.new(0, 0, -moatDistance)
		Terrain:FillBlock(frame * CFrame.new(0, -2.5, 0), Vector3.new(length, 8, MOAT_WIDTH), Enum.Material.Air)
		Terrain:FillBlock(frame * CFrame.new(0, -4.5, 0), Vector3.new(length, 4, MOAT_WIDTH), Enum.Material.Water)
		Terrain:FillBlock(frame * CFrame.new(0, -7.5, 0), Vector3.new(length, 2, MOAT_WIDTH), Enum.Material.Mud)
	end
end

local function hills(rng: Random, gateAngle: number, innerRadius: number)
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, 360)
		if angleFrom(angle, gateAngle) > 12 then
			local distance = rng:NextNumber(innerRadius, 820)
			local radius = rng:NextNumber(30, 70)
			local position = Hub.radial(angle) * Vector3.new(0, GROUND_TOP - radius * 0.65, -distance)
			Terrain:FillBall(position, radius, Enum.Material.Grass)
		end
	end
end

local function mountains(rng: Random)
	for i = 0, 17 do
		local angle = i * 20 + rng:NextNumber(-6, 6)
		local distance = rng:NextNumber(930, 990)
		local radius = rng:NextNumber(95, 140)
		local base = Hub.radial(angle) * Vector3.new(0, -radius * 0.35, -distance)
		Terrain:FillBall(base, radius, Enum.Material.Rock)
		Terrain:FillBall(base + Vector3.new(0, radius * 0.82, 0), radius * 0.3, Enum.Material.Snow)
	end
end

local function road(folder: Folder, gateAngle: number, start: number)
	Builder.part(folder, Hub.radial(gateAngle), {
		Name = "CountryRoad",
		Size = Vector3.new(12, 1, ROAD_LENGTH),
		At = CFrame.new(0, 0.1, -(start + ROAD_LENGTH / 2)),
		Color = Color3.fromRGB(176, 150, 112),
		Material = Enum.Material.Pebble,
		CastShadow = false,
	})
end

local function forest(folder: Folder, rng: Random, gateAngle: number, innerRadius: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }

	local placed, attempts = 0, 0
	while placed < 70 and attempts < 400 do
		attempts += 1
		local angle = rng:NextNumber(0, 360)
		local distance = rng:NextNumber(innerRadius, 880)
		local frame = Hub.radial(angle)
		-- Keep the road out of the gate clear.
		local lateral = math.sin(math.rad(angleFrom(angle, gateAngle))) * distance
		if angleFrom(angle, gateAngle) > 90 or lateral > 14 then
			local top = frame * Vector3.new(0, 200, -distance)
			local hit = workspace:Raycast(top, Vector3.new(0, -400, 0), params)
			if hit and hit.Material == Enum.Material.Grass then
				Builder.tree(folder, hit.Position, rng:NextNumber(1, 1.7), rng)
				placed += 1
			end
		end
	end
end

function Landscape.build(parent: Instance, moatDistance: number, sides: number, gateAngle: number): Folder
	local folder = Builder.folder(parent, "Landscape")
	local rng = Random.new(2024)
	local outside = moatDistance + MOAT_WIDTH / 2 + 30

	styleTerrain()
	-- Fill the plain in tiles to keep each terrain write small.
	local tile = PLAIN_SIZE / 5
	for x = -2, 2 do
		for z = -2, 2 do
			Terrain:FillBlock(
				CFrame.new(x * tile, GROUND_TOP - 6.5, z * tile),
				Vector3.new(tile, 13, tile),
				Enum.Material.Grass
			)
		end
	end
	moat(moatDistance, sides)
	hills(rng, gateAngle, outside + 40)
	mountains(rng)
	road(folder, gateAngle, moatDistance + MOAT_WIDTH / 2)
	forest(folder, rng, gateAngle, outside)

	return folder
end

return Landscape
