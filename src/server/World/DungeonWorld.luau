-- Room geometry is generated server-side and owned by one run.
local Rules = require(game:GetService("ReplicatedStorage").Shared.DungeonRules)
local GemConfig = require(game:GetService("ReplicatedStorage").Shared.GemConfig)
local World = {}
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
function World.build(id, rooms, origin)
	local folder = Instance.new("Folder")
	folder.Name = "Dungeon_" .. id
	folder.Parent = workspace
	local centers, gates = {}, {}
	local wallColor = Color3.fromRGB(76, 69, 66)
	for i, room in rooms do
		local center = origin + Vector3.new(room.X * Rules.Spacing, 0, room.Z * Rules.Spacing)
		centers[i] = center
		local color = GemConfig.ElementColors[Rules.Roster[room.Theme].Element]
		block(folder, "CanyonClearing", Vector3.new(64, 2, 64), center, Color3.fromRGB(103, 97, 83))
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
						wallColor
					)
				end
			else
				block(
					folder,
					"CanyonRidge",
					if dx ~= 0 then Vector3.new(5, 9, 64) else Vector3.new(64, 9, 5),
					center + Vector3.new(dx * 32, 4.5, dz * 32),
					wallColor
				)
				for segment = 1, 7 do
					local offset = (segment - 4) * 10
					local rock = block(
						folder,
						"RidgeCrown",
						if dx ~= 0 then Vector3.new(7, 4 + segment % 3, 11) else Vector3.new(11, 4 + segment % 3, 7),
						center + Vector3.new(dx * 34 + dz * offset, 9, dz * 34 + dx * offset),
						Color3.fromRGB(86 + segment % 3 * 5, 79, 73)
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
				Color3.fromRGB(66, 65, 73)
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
			block(folder, "Pillar", Vector3.new(4, 10, 4), at, wallColor)
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
				wallColor
			)
			for _, sign in { -1, 1 } do
				block(
					folder,
					"TrailRidge",
					if horizontal then Vector3.new(30, 9, 4) else Vector3.new(4, 9, 30),
					midpoint + Vector3.new(if horizontal then 0 else sign * 9, 4.5, if horizontal then sign * 9 else 0),
					wallColor
				)
			end
			local gate = block(
				folder,
				"SealedGate",
				if horizontal then Vector3.new(2, 14, 16) else Vector3.new(16, 14, 2),
				midpoint + Vector3.new(0, 7, 0),
				color,
				Enum.Material.Neon
			)
			gate.Transparency = 0.35
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
		local color = GemConfig.ElementColors[Rules.Roster[camp.Theme].Element]
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
return World
