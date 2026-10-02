--[[
	The Moon Mine's expedition site, built by the server (so everyone shares
	it and can walk around it): a cliff on the moon where terraforming has
	begun. Grey regolith and craters, green spreading out from a biodome with
	trees and a lake, atmosphere processors breathing out air, Earth in the
	sky, and a rock face veined with glowing Saga crystal under floodlights.

	MiningSite.build(at, parent) builds it and returns a Site (spawn point,
	rock spots, the crystal face). MiningSite.Current is the one in this game.
	The ground, cliff, tree trunks and big props are solid; decoration isn't.
]]
local Lighting = game:GetService("Lighting")

local MiningSite = {}

-- Where the site is in the world, and where its crystal face runs.
MiningSite.Location = CFrame.new(0, 0, 4000)
local FACE_X, FACE_Z = 12, -14

local SAGA = Color3.fromRGB(255, 184, 72)
local HOLO = Color3.fromRGB(90, 210, 255)
local HULL_DARK = Color3.fromRGB(46, 50, 60)

-- One anchored, non-colliding part. `shape` is "Ball", "Cylinder" (along X),
-- "Sphere" or "Tube" (mesh ellipsoid / mesh tube along Y, filling the size).
local function part(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: string?,
	props: { [string]: any }?
): BasePart
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 1
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "Sphere" or shape == "Tube" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = if shape == "Sphere" then Enum.MeshType.Sphere else Enum.MeshType.Cylinder
		mesh.Parent = p
	end
	for key, value in props or {} do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Something you can stand on or bump into.
local function solid(p: BasePart): BasePart
	p.CanCollide = true
	p.CanQuery = true
	return p
end

local function glow(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, shape: string?): BasePart
	local p = part(parent, cframe, size, color, Enum.Material.Neon, shape)
	p.CastShadow = false
	return p
end

local function lamp(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

export type Layout = {
	Spawn: CFrame, -- where expeditions arrive (feet), facing the cliff
	RockSpots: { CFrame }, -- one per rock in a wall (on the ground)
	Face: CFrame, -- centre of the rock face, facing out (+Z toward the miner)
	FaceSize: Vector2,
}
export type Site = Layout & { Model: Model }

-- Where things go at a site placed at `at` (no parts are made).
function MiningSite.layout(at: CFrame): Layout
	local function c(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	-- The rocks: a loose field at the foot of the crystal face.
	local spots = {}
	local field = Random.new(17)
	for row = 0, 3 do
		for column = 0, 5 do
			local x = FACE_X - 27 + column * 4.6 + field:NextNumber(-0.7, 0.7)
			local z = FACE_Z + 6 + row * 4 + field:NextNumber(-0.6, 0.6)
			table.insert(spots, c(x, 0, z) * CFrame.Angles(0, field:NextNumber() * math.pi * 2, 0))
		end
	end
	local pad = c(-4, 0, 18)
	return {
		Spawn = CFrame.lookAt(pad.Position, c(FACE_X - 16, 0, FACE_Z).Position),
		RockSpots = spots,
		Face = c(FACE_X - 16, 6, FACE_Z + 3),
		FaceSize = Vector2.new(8, 6),
	}
end

function MiningSite.build(at: CFrame, parent: Instance): Site
	local m = model("MiningSite")
	local REGOLITH = Color3.fromRGB(150, 150, 156)
	local ROCK = Color3.fromRGB(108, 104, 114)
	local GRASS = Color3.fromRGB(88, 156, 72)
	local GRASS_LIGHT = Color3.fromRGB(122, 182, 88)
	local WHITE = Color3.fromRGB(222, 226, 232)
	local METAL = Color3.fromRGB(80, 84, 94)
	local rng = Random.new(91)
	local function c(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	local function disc(x: number, y: number, z: number, w: number, d: number, h: number, color: Color3, material)
		return part(m, c(x, y, z), Vector3.new(w, h, d), color, material, "Sphere")
	end

	-- The ground: regolith with craters.
	solid(part(m, c(0, -2, 0), Vector3.new(4, 760, 760), REGOLITH, Enum.Material.Slate, "Cylinder", {
		CFrame = c(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	}))
	for _ = 1, 14 do
		local angle = rng:NextNumber() * math.pi * 2
		local dist = rng:NextNumber(110, 320)
		local size = rng:NextNumber(16, 44)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		disc(x, 0.1, z, size, size, 1.2, Color3.fromRGB(122, 122, 130), Enum.Material.Slate)
		disc(x, 0.5, z, size * 0.7, size * 0.7, 0.8, Color3.fromRGB(98, 98, 106), Enum.Material.Slate)
	end

	-- Terraforming: green spreading out across the regolith from the dome.
	for _ = 1, 30 do
		local x = rng:NextNumber(-150, 0)
		local z = rng:NextNumber(-130, 30)
		local s = rng:NextNumber(10, 34)
		disc(
			x,
			0.15,
			z,
			s,
			s * rng:NextNumber(0.6, 1),
			0.7,
			if rng:NextNumber() < 0.5 then GRASS else GRASS_LIGHT,
			Enum.Material.Grass
		)
	end
	-- Little tufts and flowers at the edges of the green.
	for _ = 1, 50 do
		local x = rng:NextNumber(-140, -6)
		local z = rng:NextNumber(-120, 26)
		disc(x, 0.6, z, 1.6, 1.6, 1.2, GRASS_LIGHT, Enum.Material.LeafyGrass)
		if rng:NextNumber() < 0.35 then
			local petal = ({
				Color3.fromRGB(255, 214, 90),
				Color3.fromRGB(255, 140, 190),
				Color3.fromRGB(170, 140, 255),
			})[rng:NextInteger(1, 3)]
			glow(m, c(x + 0.4, 1.3, z), Vector3.one * 0.5, petal, "Ball")
		end
	end

	-- The biodome: grass, a lake and trees under glass.
	local DOME_X, DOME_Z, DOME_R = -62, -44, 30
	disc(DOME_X, 0.3, DOME_Z, DOME_R * 2, DOME_R * 2, 1, GRASS, Enum.Material.Grass)
	part(
		m,
		c(DOME_X + 4, 0.25, DOME_Z + 8),
		Vector3.new(24, 0.6, 14),
		Color3.fromRGB(70, 150, 210),
		Enum.Material.Glass,
		"Sphere",
		{
			Transparency = 0.15,
			Reflectance = 0.2,
		}
	)
	local function tree(x: number, z: number, h: number)
		solid(
			part(m, c(x, h / 2, z), Vector3.new(1.4, h, 1.4), Color3.fromRGB(110, 78, 52), Enum.Material.Wood, "Tube")
		)
		for i = 1, 3 do
			local s = h * rng:NextNumber(0.45, 0.7)
			part(
				m,
				c(x + rng:NextNumber(-1.5, 1.5), h + rng:NextNumber(-1, 1.5) + i * 0.6, z + rng:NextNumber(-1.5, 1.5)),
				Vector3.new(s, s * 0.85, s),
				if i == 2 then Color3.fromRGB(66, 138, 64) else Color3.fromRGB(84, 160, 74),
				Enum.Material.LeafyGrass,
				"Ball"
			)
		end
	end
	for _, spec in
		{
			{ -74, -56, 10 },
			{ -66, -64, 8 },
			{ -50, -58, 9 },
			{ -78, -36, 8 },
			{ -54, -30, 7 },
			{ -70, -24, 9 },
			{ -42, -44, 6 },
			-- Young trees planted out in the open.
			{ -24, -18, 5 },
			{ -30, 4, 4 },
			{ -96, -10, 6 },
			{ -110, -60, 7 },
			{ -18, -40, 4 },
		}
	do
		tree(spec[1], spec[2], spec[3])
	end
	part(
		m,
		c(DOME_X, 0, DOME_Z),
		Vector3.one * DOME_R * 2,
		Color3.fromRGB(170, 220, 255),
		Enum.Material.Glass,
		"Ball",
		{
			Transparency = 0.72,
			CastShadow = false,
		}
	)
	solid(
		part(
			m,
			c(DOME_X, 0.6, DOME_Z),
			Vector3.new(1.4, DOME_R * 2 + 1.5, DOME_R * 2 + 1.5),
			METAL,
			Enum.Material.Metal,
			"Cylinder",
			{
				CFrame = c(DOME_X, 0.6, DOME_Z) * CFrame.Angles(0, 0, math.rad(90)),
			}
		)
	)

	-- Atmosphere processors breathing out the new air.
	for _, spec in { { -118, -110, 46 }, { 46, -86, 52 }, { -20, -150, 40 } } do
		local x, z, h = spec[1], spec[2], spec[3]
		solid(part(m, c(x, h / 2, z), Vector3.new(7, h, 7), WHITE, Enum.Material.SmoothPlastic, "Tube"))
		solid(part(m, c(x, 1.5, z), Vector3.new(12, 3, 12), METAL, Enum.Material.DiamondPlate, "Tube"))
		for i = 1, 3 do
			glow(m, c(x, h * i / 4, z), Vector3.new(7.6, 0.6, 7.6), HOLO, "Tube")
		end
		part(m, c(x, h + 1.5, z), Vector3.new(10, 3, 10), METAL, Enum.Material.Metal, "Tube")
		for i = 1, 4 do
			local puff = part(
				m,
				c(x + rng:NextNumber(-3, 3), h + 6 + i * 6, z + rng:NextNumber(-3, 3)),
				Vector3.one * (6 + i * 4),
				Color3.fromRGB(235, 242, 250),
				Enum.Material.SmoothPlastic,
				"Ball",
				{ Transparency = 0.55 + i * 0.1, CastShadow = false }
			)
			if i == 1 then
				local mist = Instance.new("ParticleEmitter")
				mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
				mist.Color = ColorSequence.new(Color3.fromRGB(230, 240, 250))
				mist.Transparency = NumberSequence.new(0.5, 1)
				mist.Size = NumberSequence.new(4, 14)
				mist.Lifetime = NumberRange.new(4, 6)
				mist.Rate = 3
				mist.Speed = NumberRange.new(3, 5)
				mist.SpreadAngle = Vector2.new(12, 12)
				mist.Parent = puff
			end
		end
	end

	-- The rock face, veined with Saga crystal.
	solid(part(m, c(FACE_X + 12, 11, FACE_Z - 9), Vector3.new(70, 24, 16), ROCK, Enum.Material.Slate))
	for _ = 1, 22 do
		local x = FACE_X + rng:NextNumber(-26, 34)
		local h = rng:NextNumber(8, 22)
		local w = rng:NextNumber(6, 13)
		solid(
			part(
				m,
				c(x, h / 2 - 1, FACE_Z - rng:NextNumber(0, 4))
					* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.3, 0.3)),
				Vector3.new(w, h, w * 0.8),
				ROCK:Lerp(Color3.fromRGB(140, 134, 128), rng:NextNumber(0, 0.6)),
				if rng:NextNumber() < 0.6 then Enum.Material.Slate else Enum.Material.Basalt
			)
		)
	end
	-- Fallen rubble at the foot of the cliff.
	for _ = 1, 16 do
		local s = rng:NextNumber(1, 3)
		part(
			m,
			c(FACE_X + rng:NextNumber(-24, 10), s * 0.3, FACE_Z + rng:NextNumber(0.5, 2.5))
				* CFrame.Angles(rng:NextNumber() * 3, rng:NextNumber() * 3, 0),
			Vector3.new(s, s * 0.8, s * 1.1),
			ROCK:Lerp(REGOLITH, 0.4),
			Enum.Material.Slate
		)
	end
	-- Crystal veins across the face, and clusters breaking through.
	for i = 1, 7 do
		local color = if i % 3 == 0 then HOLO else SAGA
		glow(
			m,
			c(FACE_X + rng:NextNumber(-24, 2), rng:NextNumber(3, 13), FACE_Z + 3.6)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.9, 0.9)),
			Vector3.new(rng:NextNumber(5, 11), 0.3, 0.3),
			color
		)
	end
	for _, spec in { { -22, 4, SAGA }, { -16, 9, HOLO }, { -10, 3, SAGA }, { -4, 11, SAGA }, { 2, 7, HOLO } } do
		local cluster = c(FACE_X + spec[1], spec[2], FACE_Z + 3.4)
		for k = 1, 4 do
			local shard = part(
				m,
				cluster
					* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.9, 0.9))
					* CFrame.new(0, 0.6 + k * 0.2, 0),
				Vector3.new(0.6, rng:NextNumber(1.6, 3), 0.6),
				spec[3],
				Enum.Material.Glass,
				nil,
				{ Transparency = 0.15, CastShadow = false }
			)
			if k == 1 then
				lamp(shard, spec[3], 10, 1.4)
			end
		end
		glow(m, cluster, Vector3.one * 0.9, spec[3], "Ball")
	end

	-- Floodlights on the face, an ore cart on rails and supply crates.
	for _, x in { -22, 16 } do
		solid(part(m, c(x, 5, 1), Vector3.new(0.6, 10, 0.6), METAL, Enum.Material.Metal, "Tube"))
		local head = part(
			m,
			CFrame.lookAt(c(x, 10, 1).Position, c(FACE_X, 5, FACE_Z).Position),
			Vector3.new(2.4, 1.4, 1.2),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		local lens =
			glow(m, head.CFrame * CFrame.new(0, 0, -0.65), Vector3.new(2, 1, 0.1), Color3.fromRGB(255, 244, 214))
		local beam = Instance.new("SpotLight")
		beam.Color = Color3.fromRGB(255, 240, 210)
		beam.Range = 40
		beam.Brightness = 3
		beam.Angle = 60
		beam.Face = Enum.NormalId.Front
		beam.Parent = lens
	end
	for _, x in { -1.4, 1.4 } do
		part(
			m,
			c(14 + x, 0.25, 6) * CFrame.Angles(0, math.rad(20), 0),
			Vector3.new(0.3, 0.3, 30),
			METAL,
			Enum.Material.Metal
		)
	end
	local cart = c(15, 1.8, 3) * CFrame.Angles(0, math.rad(20), 0)
	solid(part(m, cart, Vector3.new(4, 2.2, 5.5), Color3.fromRGB(200, 120, 50), Enum.Material.Metal))
	for _, offset in { { -1.2, -1.6 }, { 1.2, -1.6 }, { -1.2, 1.6 }, { 1.2, 1.6 } } do
		part(
			m,
			cart * CFrame.new(offset[1] * 1.6, -1.2, offset[2]),
			Vector3.new(0.5, 1, 1),
			HULL_DARK,
			Enum.Material.Metal,
			"Cylinder"
		)
	end
	for k = 1, 5 do
		part(
			m,
			cart * CFrame.new(rng:NextNumber(-1.2, 1.2), 1.3, rng:NextNumber(-2, 2)),
			Vector3.one * rng:NextNumber(0.8, 1.4),
			ROCK,
			Enum.Material.Slate,
			"Ball"
		)
		if k <= 2 then
			glow(
				m,
				cart * CFrame.new(rng:NextNumber(-1, 1), 1.6, rng:NextNumber(-1.5, 1.5)),
				Vector3.new(0.4, 0.9, 0.4),
				SAGA
			)
		end
	end
	for _, spec in { { -26, 6 }, { -28.5, 7.5 }, { -27, 8.8 } } do
		solid(
			part(
				m,
				c(spec[1], 1, spec[2]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
				Vector3.new(2, 2, 2),
				Color3.fromRGB(70, 78, 92),
				Enum.Material.DiamondPlate
			)
		)
		glow(m, c(spec[1], 2.05, spec[2]), Vector3.new(1.6, 0.1, 0.3), HOLO)
	end

	-- Earth, already looking a little like home, hangs over the valley.
	part(m, c(-560, 330, -900), Vector3.one * 380, Color3.fromRGB(56, 112, 190), Enum.Material.SmoothPlastic, "Ball")
	part(m, c(-544, 352, -884), Vector3.one * 340, Color3.fromRGB(92, 170, 102), Enum.Material.SmoothPlastic, "Ball", {
		Transparency = 0.6,
	})
	part(m, c(-566, 338, -870), Vector3.one * 394, Color3.fromRGB(240, 246, 255), Enum.Material.SmoothPlastic, "Ball", {
		Transparency = 0.82,
	})

	-- The arrival pad, where the lift drops expeditions off.
	local PAD = c(-4, 0, 18)
	solid(
		part(m, PAD * CFrame.new(0, 0.2, 0), Vector3.new(0.4, 12, 12), METAL, Enum.Material.DiamondPlate, "Cylinder", {
			CFrame = PAD * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
	)
	glow(m, PAD * CFrame.new(0, 0.42, 0), Vector3.new(0.08, 12.4, 12.4), HOLO, "Cylinder").CFrame = PAD
		* CFrame.new(0, 0.42, 0)
		* CFrame.Angles(0, 0, math.rad(90))

	m.Parent = parent
	local layout = MiningSite.layout(at)
	local site: Site = {
		Model = m,
		Spawn = layout.Spawn,
		RockSpots = layout.RockSpots,
		Face = layout.Face,
		FaceSize = layout.FaceSize,
	}
	MiningSite.Current = site
	return site
end

MiningSite.Current = nil :: Site?

-- The site in this game: the server builds it once; clients find it here.
function MiningSite.find(): Model?
	return workspace:FindFirstChild("MiningSite") :: Model?
end

-- Terraformed: still a starry sky, but with a thin new atmosphere and warm light.
function MiningSite.lighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 116, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 168, 184)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(150, 180, 220)
	atmosphere.Decay = Color3.fromRGB(70, 90, 130)
	atmosphere.Haze = 0.6
	atmosphere.Glare = 0
	atmosphere.Parent = Lighting
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
end

return MiningSite
