-- Room geometry is generated server-side and owned by one run.
local Rules = require(game:GetService("ReplicatedStorage").Shared.DungeonRules)
local GemConfig = require(game:GetService("ReplicatedStorage").Shared.GemConfig)
local FallenMiners = require(script.Parent.FallenMiners)
local World = {}
-- A run's look: the canyon (every dungeon's), or the Rot Beachhead's
-- (Shared.DungeonRules.First): wet black sand, the invaders' wrecked hull
-- for walls, the rot's glow for lamps and crystals, membranes for gates.
local ROT = Color3.fromRGB(70, 22, 84)
local ROT_DARK = Color3.fromRGB(36, 12, 44)
local ROT_GLOW = Color3.fromRGB(90, 255, 110)
local HULL = Color3.fromRGB(62, 68, 80)
local RUST = Color3.fromRGB(104, 56, 34)
World.Themes = {
	Canyon = {
		Floor = Color3.fromRGB(103, 97, 83), FloorMaterial = Enum.Material.Slate,
		Wall = Color3.fromRGB(76, 69, 66), WallMaterial = Enum.Material.Slate,
		Crown = nil, CrownMaterial = Enum.Material.Slate,
		Crag = Color3.fromRGB(66, 65, 73), CragMaterial = Enum.Material.Slate,
		Glow = nil, Gate = nil, GateMaterial = Enum.Material.Neon, GateTransparency = 0.35,
		Trail = Color3.fromRGB(76, 69, 66), TrailMaterial = Enum.Material.Slate,
	},
	Rot = {
		Floor = Color3.fromRGB(46, 42, 44), FloorMaterial = Enum.Material.Sand,
		Wall = HULL, WallMaterial = Enum.Material.DiamondPlate,
		Crown = RUST, CrownMaterial = Enum.Material.CorrodedMetal,
		Crag = Color3.fromRGB(40, 44, 54), CragMaterial = Enum.Material.Metal,
		Glow = ROT_GLOW, Gate = Color3.fromRGB(150, 60, 190), GateMaterial = Enum.Material.Glass, GateTransparency = 0.25,
		Trail = Color3.fromRGB(58, 62, 72), TrailMaterial = Enum.Material.DiamondPlate,
	},
}
local function block(parent, name, size, at, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end
-- Neutral fixtures reveal material and facial detail without washing out element colors.
local function fillLight(parent, at, range, brightness)
	local fixture =
		block(parent, "CombatFill", Vector3.new(5, 0.25, 2), at, Color3.fromRGB(215, 228, 245), Enum.Material.Neon)
	fixture.CanCollide = false
	fixture.CanTouch = false
	fixture.CanQuery = false
	fixture.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(225, 233, 247)
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = fixture
end
function World.build(id, rooms, origin, theme)
	local T = World.Themes[theme or "Canyon"] or World.Themes.Canyon
	local folder = Instance.new("Folder")
	folder.Name = "Dungeon_" .. id
	folder.Parent = workspace
	local centers, gates = {}, {}
	local wallColor = T.Wall
	local rng = Random.new()
	for i, room in rooms do
		local center = origin + Vector3.new(room.X * Rules.Spacing, 0, room.Z * Rules.Spacing)
		centers[i] = center
		local color = T.Glow or GemConfig.ElementColors[Rules.specOf(room).Element]
		block(folder, "CanyonClearing", Vector3.new(64, 2, 64), center, T.Floor, T.FloorMaterial)
		fillLight(folder, center + Vector3.new(-16, 16, 0), 48, 1.7)
		fillLight(folder, center + Vector3.new(16, 16, 0), 48, 1.7)
		local doors = {}
		for _, index in { i - 1, i + 1 } do
			local neighbor = rooms[index]
			if neighbor then
				doors[(neighbor.X - room.X) .. ":" .. (neighbor.Z - room.Z)] = true
			end
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local dx, dz = d[1], d[2]
			if doors[dx .. ":" .. dz] then
				for _, sign in { -1, 1 } do
					local at = center + Vector3.new(dx * 32 + dz * sign * 20, 4.5, dz * 32 + dx * sign * 20)
					block(
						folder,
						"TrailCliff",
						if dx ~= 0 then Vector3.new(5, 9, 24) else Vector3.new(24, 9, 5),
						at,
						wallColor,
						T.WallMaterial
					)
				end
			else
				block(
					folder,
					"CanyonRidge",
					if dx ~= 0 then Vector3.new(5, 9, 64) else Vector3.new(64, 9, 5),
					center + Vector3.new(dx * 32, 4.5, dz * 32),
					wallColor,
					T.WallMaterial
				)
				for segment = 1, 7 do
					local offset = (segment - 4) * 10
					local rock = block(
						folder,
						"RidgeCrown",
						if dx ~= 0 then Vector3.new(7, 4 + segment % 3, 11) else Vector3.new(11, 4 + segment % 3, 7),
						center + Vector3.new(dx * 34 + dz * offset, 9, dz * 34 + dx * offset),
						T.Crown or Color3.fromRGB(86 + segment % 3 * 5, 79, 73),
						T.CrownMaterial
					)
					rock.CFrame *= CFrame.Angles(0.04 * (segment % 3 - 1), 0, 0.06 * (segment % 2))
				end
			end
		end
		-- Broken geological silhouettes outside the playable clearing, clear combat floor inside.
		for n = 1, 7, 2 do
			local angle = n * math.pi / 4
			local ridge = block(
				folder,
				"DistantCrag",
				Vector3.new(9, 12 + n % 3 * 4, 8),
				center + Vector3.new(math.cos(angle) * 43, 6, math.sin(angle) * 43),
				T.Crag,
				T.CragMaterial
			)
			ridge.CFrame *= CFrame.Angles(0.12, angle, 0.18)
		end
		for n = 1, 3 do
			local crystal = block(
				folder,
				"CanyonOre",
				Vector3.new(1.5, 3 + n, 1.5),
				center + Vector3.new(25 + n, 2, 18 + n),
				color,
				Enum.Material.Neon
			)
			crystal.CFrame *= CFrame.Angles(0.15, n, 0.2)
		end
		for n = 1, room.Pillars do
			local angle = (n - 1) * math.pi / 2 + math.pi / 4
			local at = center + Vector3.new(math.cos(angle) * 24, 5, math.sin(angle) * 24)
			block(folder, "Pillar", Vector3.new(4, 10, 4), at, wallColor, T.WallMaterial)
			local light = block(
				folder,
				"ElementLamp",
				Vector3.new(4.1, 0.35, 4.1),
				at + Vector3.new(0, 4, 0),
				color,
				Enum.Material.Neon
			)
			local glow = Instance.new("PointLight")
			glow.Color = color
			glow.Range = 35
			glow.Brightness = 1.4
			glow.Shadows = false
			glow.Parent = light
		end
		-- What's left of the crews who came before (Server.World.FallenMiners):
		-- one by a wall, and round the boss more of them and their heap.
		local doorDirs = {}
		for _, index in { i - 1, i + 1 } do
			local neighbor = rooms[index]
			if neighbor then
				table.insert(doorDirs, Vector3.new(neighbor.X - room.X, 0, neighbor.Z - room.Z).Unit)
			end
		end
		local remains = { Glow = color, Shards = true, Doors = doorDirs }
		if room.Boss then
			local back = if #doorDirs > 0 then -doorDirs[1] else Vector3.new(0, 0, 1)
			local heapAt = center + back * 20 + Vector3.new(-back.Z, 0, back.X) * 12 + Vector3.new(0, 1, 0)
			FallenMiners.heap(folder, heapAt, -back, rng, remains)
			remains.Avoid = { { At = heapAt, Radius = 11 } }
		end
		FallenMiners.scatter(
			folder,
			center + Vector3.new(0, 1, 0),
			58,
			if room.Boss then FallenMiners.Count.BossRoom else FallenMiners.Count.Room,
			rng,
			remains
		)
		if i > 1 then
			local previous = centers[i - 1]
			local delta = center - previous
			local midpoint = (center + previous) / 2
			local horizontal = delta.X ~= 0
			fillLight(folder, midpoint + Vector3.new(0, 11, 0), 30, 1.4)
			block(
				folder,
				"ConnectingTrail",
				if horizontal then Vector3.new(30, 2, 16) else Vector3.new(16, 2, 30),
				midpoint,
				T.Trail,
				T.TrailMaterial
			)
			for _, sign in { -1, 1 } do
				block(
					folder,
					"TrailRidge",
					if horizontal then Vector3.new(30, 9, 4) else Vector3.new(4, 9, 30),
					midpoint + Vector3.new(if horizontal then 0 else sign * 9, 4.5, if horizontal then sign * 9 else 0),
					wallColor,
					T.WallMaterial
				)
			end
			local gate = block(
				folder,
				"SealedGate",
				if horizontal then Vector3.new(2, 14, 16) else Vector3.new(16, 14, 2),
				midpoint + Vector3.new(0, 7, 0),
				T.Gate or color,
				T.GateMaterial
			)
			gate.Transparency = T.GateTransparency
			gates[i - 1] = gate
		end
	end
	return { Folder = folder, Centers = centers, Gates = gates }
end
function World.buildOpen(id, camps, origin)
	local folder = Instance.new("Folder")
	folder.Name = "Dungeon_" .. id
	folder.Parent = workspace
	local radius = Rules.OpenRadius
	block(
		folder,
		"ExpeditionBedrock",
		Vector3.new(radius * 2, 4, radius * 2),
		origin - Vector3.new(0, 1, 0),
		Color3.fromRGB(78, 87, 101)
	)
	local centers, ore = {}, {}
	local rng = Random.new()
	-- Broken perimeter escarpment, leaving the entire interior traversable.
	for i = 1, 48 do
		local angle = i / 48 * math.pi * 2
		local at = origin + Vector3.new(math.cos(angle) * (radius - 8), 8, math.sin(angle) * (radius - 8))
		local rock =
			block(folder, "RimRock", Vector3.new(28, rng:NextInteger(16, 30), 24), at, Color3.fromRGB(53, 62, 80))
		rock.CFrame *= CFrame.Angles(0, angle, 0.12)
	end
	for i, camp in camps do
		local center = origin + Vector3.new(camp.X * Rules.Spacing, 0, camp.Z * Rules.Spacing)
		centers[i] = center
		local color = GemConfig.ElementColors[Rules.specOf(camp).Element]
		ore[i] = center + Vector3.new(0, 3, 0)
		for n = 1, 5 do
			local angle = n * math.pi * 2 / 5
			local crystal = block(
				folder,
				"FeedingOre",
				Vector3.new(3, 5 + n % 3, 3),
				center + Vector3.new(math.cos(angle) * 4, 3, math.sin(angle) * 4),
				color,
				Enum.Material.Neon
			)
			crystal.CFrame *= CFrame.Angles(0.2, angle, 0.2)
		end
		fillLight(folder, center + Vector3.new(0, 20, 0), 48, 1.5)
		if camp.Bandit then
			block(
				folder,
				"BanditSupplyCrate",
				Vector3.new(6, 4, 4),
				center + Vector3.new(12, 2, 8),
				Color3.fromRGB(102, 39, 43),
				Enum.Material.Metal
			)
			block(
				folder,
				"BanditBeacon",
				Vector3.new(1, 9, 1),
				center + Vector3.new(15, 4, 5),
				Color3.fromRGB(223, 62, 62),
				Enum.Material.Neon
			)
		elseif camp.Boss then
			local plinth =
				block(folder, "ColossusPlateau", Vector3.new(58, 2, 58), center, Color3.fromRGB(98, 105, 117))
			for n = 1, 8 do
				local a = n * math.pi / 4
				block(
					folder,
					"AncientMonolith",
					Vector3.new(5, 16, 5),
					center + Vector3.new(math.cos(a) * 38, 8, math.sin(a) * 38),
					Color3.fromRGB(48, 56, 74)
				)
			end
		end
	end
	-- Low scattered outcrops, kept away from camps and the arrival clearing.
	for i = 1, 60 do
		local at = origin + Vector3.new(rng:NextInteger(-225, 225), 1, rng:NextInteger(-200, 220))
		local clear = true
		for _, center in centers do
			if (at - center).Magnitude < 34 then
				clear = false
				break
			end
		end
		if clear then
			local rock = block(
				folder,
				"OpenWorldOutcrop",
				Vector3.new(rng:NextInteger(4, 10), rng:NextInteger(3, 7), rng:NextInteger(4, 10)),
				at,
				Color3.fromRGB(65, 76, 92)
			)
			rock.CFrame *= CFrame.Angles(0, rng:NextNumber() * math.pi, 0.15)
		end
	end
	local arrival = origin + Vector3.new(0, 0, -225)
	fillLight(folder, arrival + Vector3.new(0, 15, 0), 48, 2)
	return {
		Folder = folder,
		Centers = centers,
		Gates = {},
		Ore = ore,
		Origin = origin,
		Arrival = arrival,
		Radius = radius,
	}
end
-- The Rot Beachhead's dressing over the canyon rooms (Shared.DungeonRules.First):
-- glowing rot pods round each room, the rot's purple growth along its walls,
-- and broken hull plates leaning where the invaders' ship came down.
local function scenery(part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end
local function ball(folder, name, size, at, color, material)
	local part = scenery(block(folder, name, Vector3.new(size, size, size), at, color, material or Enum.Material.SmoothPlastic))
	part.Shape = Enum.PartType.Ball
	return part
end
local function light(part, color, range, brightness)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = range
	glow.Brightness = brightness
	glow.Shadows = false
	glow.Parent = part
	return glow
end
-- A flat pool on the floor (`at`: its middle, on the floor's top).
local function pool(folder, name, at, diameter, color, transparency)
	local part = scenery(block(folder, name, Vector3.new(0.2, diameter, diameter), at, color, Enum.Material.Neon))
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	part.Transparency = transparency
	return part
end
-- Spores drifting up through a room (`at`: its floor's middle).
local function spores(folder, at)
	local emitter = scenery(block(folder, "RotSpores", Vector3.new(52, 0.2, 52), at + Vector3.new(0, 1.5, 0), ROT_GLOW))
	emitter.Transparency = 1
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "Spores"
	fx.Color = ColorSequence.new(ROT_GLOW, Color3.fromRGB(190, 120, 255))
	fx.LightEmission = 1
	fx.Rate = 7
	fx.Lifetime = NumberRange.new(6, 9)
	fx.Speed = NumberRange.new(0.6, 1.6)
	fx.EmissionDirection = Enum.NormalId.Top
	fx.SpreadAngle = Vector2.new(25, 25)
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.5, 0.32), NumberSequenceKeypoint.new(1, 0) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.25), NumberSequenceKeypoint.new(1, 1) })
	fx.Parent = emitter
end
function World.dressBeachhead(folder, centers, rng)
	rng = rng or Random.new()
	local last = #centers
	for i, center in centers do
		local floor = center + Vector3.new(0, 1.05, 0) -- (the floor's top)
		-- Rot pods on stalks round the room, glowing.
		for n = 1, 4 do
			local a = (n - 0.5) / 4 * math.pi * 2 + i
			local at = center + Vector3.new(math.cos(a) * 25, 0, math.sin(a) * 25)
			scenery(block(folder, "RotStalk", Vector3.new(0.8, 2.6, 0.8), at + Vector3.new(0, 2.3, 0), ROT_DARK))
			local pod = ball(folder, "RotPod", 2.4, at + Vector3.new(0, 4.4, 0), ROT_GLOW, Enum.Material.Neon)
			light(pod, ROT_GLOW, 18, 1.2)
		end
		-- The rot's growth along the walls.
		for n = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(26, 30)
			local size = rng:NextNumber(3, 6.5)
			local blob = ball(folder, "RotGrowth", size, center + Vector3.new(math.cos(a) * r, size * 0.3, math.sin(a) * r), if n % 3 == 0 then ROT_DARK else ROT)
			if n % 2 == 0 then
				ball(folder, "RotSpot", 1.1, blob.Position + Vector3.new(0, size * 0.42, 0), ROT_GLOW, Enum.Material.Neon)
			end
		end
		-- Tendrils up the walls, their tips lit.
		for n = 1, 6 do
			local a = (n + rng:NextNumber(-0.3, 0.3)) / 6 * math.pi * 2
			local r = rng:NextNumber(28.5, 30.5)
			local h = rng:NextNumber(8, 14)
			local base = center + Vector3.new(math.cos(a) * r, 1, math.sin(a) * r)
			local lean = CFrame.lookAt(base, center) * CFrame.Angles(-rng:NextNumber(0.15, 0.35), 0, 0)
			local tendril = scenery(block(folder, "RotTendril", Vector3.new(0.9, h, 0.9), base, ROT_DARK))
			tendril.CFrame = lean * CFrame.new(0, h / 2, 0)
			ball(folder, "RotTip", 1.3, (lean * CFrame.new(0, h, 0)).Position, ROT_GLOW, Enum.Material.Neon)
		end
		-- Slime pools on the floor, clear of the middle (where the fight is).
		for n = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(14, 24)
			pool(folder, "RotSlime", floor + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(5, 9), Color3.fromRGB(70, 200, 90), 0.3)
		end
		-- Hull plates where the invaders' ship came down.
		for n = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local plate = scenery(block(folder, "HullPlate", Vector3.new(rng:NextNumber(6, 10), rng:NextNumber(7, 12), 0.8), center + Vector3.new(math.cos(a) * 30, 4, math.sin(a) * 30), if n == 2 then RUST else HULL, Enum.Material.DiamondPlate))
			plate.CFrame = CFrame.lookAt(plate.Position, center + Vector3.new(0, 4, 0)) * CFrame.Angles(rng:NextNumber(-0.35, 0.1), 0, rng:NextNumber(-0.25, 0.25))
		end
		spores(folder, floor)
		if i == last then
			-- The Nest: a stain of rot where the boss stands, a ring of its
			-- growth, egg sacs at the back, and the ship's nose behind it all.
			local back = if last > 1 then (center - centers[last - 1]).Unit else Vector3.new(0, 0, 1)
			local side = Vector3.new(-back.Z, 0, back.X)
			pool(folder, "NestStain", floor + Vector3.new(0, 0.02, 0), 26, ROT, 0.45)
			pool(folder, "NestGlow", floor + Vector3.new(0, 0.04, 0), 12, ROT_GLOW, 0.75)
			for n = 1, 12 do
				local a = n / 12 * math.pi * 2
				local size = rng:NextNumber(4, 7)
				ball(folder, "NestRing", size, center + Vector3.new(math.cos(a) * 27, size * 0.25, math.sin(a) * 27), if n % 2 == 0 then ROT else ROT_DARK)
			end
			for n = 1, 6 do
				local at = center + back * rng:NextNumber(20, 25) + side * rng:NextNumber(-12, 12) + Vector3.new(0, 2.5, 0)
				local sac = ball(folder, "EggSac", rng:NextNumber(3, 4.5), at, Color3.fromRGB(150, 60, 190), Enum.Material.Glass)
				sac.Transparency = 0.35
				local core = ball(folder, "EggCore", 1.4, at, ROT_GLOW, Enum.Material.Neon)
				light(core, ROT_GLOW, 10, 0.8)
			end
			local noseAt = center + back * 58 + Vector3.new(0, 9, 0)
			local nose = scenery(block(folder, "ShipNose", Vector3.new(30, 16, 46), noseAt, HULL, Enum.Material.DiamondPlate))
			nose.CFrame = CFrame.lookAt(noseAt, noseAt - back) * CFrame.Angles(0.42, 0, 0.12)
			local stripe = scenery(block(folder, "ShipStripe", Vector3.new(30.4, 2.4, 46.4), noseAt, RUST, Enum.Material.CorrodedMetal))
			stripe.CFrame = nose.CFrame * CFrame.new(0, 3, 0)
			local vent = scenery(block(folder, "ShipVent", Vector3.new(8, 3, 1), noseAt, ROT_GLOW, Enum.Material.Neon))
			vent.CFrame = nose.CFrame * CFrame.new(0, -2, -23.2)
			light(vent, ROT_GLOW, 40, 2)
		end
	end
end

-- A beam over the room to go to next (the first dungeon's way on): its
-- name over it. Returns the beam (destroy it as the room starts).
function World.beacon(folder, center, nest)
	local color = if nest then Color3.fromRGB(255, 96, 96) else ROT_GLOW
	local beam = scenery(block(folder, "NextBeacon", Vector3.new(2.5, 140, 2.5), center + Vector3.new(0, 70, 0), color, Enum.Material.Neon))
	beam.Transparency = 0.45
	light(beam, color, 30, 2)
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.AlwaysOnTop = true
	sign.Size = UDim2.fromOffset(180, 40)
	sign.StudsOffsetWorldSpace = Vector3.new(0, -52, 0)
	sign.MaxDistance = 400
	sign.LightInfluence = 0
	local words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.Size = UDim2.fromScale(1, 1)
	words.Font = Enum.Font.GothamBlack
	words.TextSize = 20
	words.TextColor3 = color
	words.TextStrokeTransparency = 0.2
	words.Text = if nest then "THE NEST ▼" else "NEXT ROOM ▼"
	words.Parent = sign
	sign.Parent = beam
	return beam
end

return World
