-- The kingdom walls: a sixteen-sided curtain wall with round blue-roofed
-- towers, banners, and a gatehouse with a drawbridge over the moat. Also
-- plants the tree-lined avenue to the gate and gardens between the zones.
local Builder = require(script.Parent.Builder)
local Hub = require(script.Parent.Hub)

local C = Builder.Colors

local SIDES = 16
local RADIUS = 305 -- plaza centre to each corner tower
local WALL_HEIGHT = 34
local WALL_THICKNESS = 8
local GATE_WIDTH = 22
local GATE_HEIGHT = 26
local TOWER_RADIUS = 11

local Kingdom = {}

Kingdom.GateAngle = 180
Kingdom.Apothem = RADIUS * math.cos(math.pi / SIDES) -- plaza centre to the middle of each wall
Kingdom.MoatDistance = Kingdom.Apothem + 18

local function corner(k: number): Vector3
	local angle = math.rad(360 / SIDES * (k + 0.5))
	return Vector3.new(RADIUS * math.sin(angle), 0, -RADIUS * math.cos(angle))
end

local function wallBlock(folder: Folder, frame: CFrame, x: number, width: number, y: number, height: number)
	Builder.part(folder, frame, {
		Name = "CurtainWall",
		Size = Vector3.new(width, height, WALL_THICKNESS),
		At = CFrame.new(x, y + height / 2, 0),
		Color = C.Stone,
		Material = Enum.Material.Cobblestone,
	})
end

-- One straight run of wall. `frame` sits at the run's midpoint with -Z facing out.
local function wallSide(folder: Folder, frame: CFrame, length: number, isGate: boolean)
	if isGate then
		local side = (length - GATE_WIDTH) / 2
		wallBlock(folder, frame, -(GATE_WIDTH + side) / 2, side, 0, WALL_HEIGHT)
		wallBlock(folder, frame, (GATE_WIDTH + side) / 2, side, 0, WALL_HEIGHT)
		wallBlock(folder, frame, 0, GATE_WIDTH, GATE_HEIGHT, WALL_HEIGHT - GATE_HEIGHT)
	else
		wallBlock(folder, frame, 0, length, 0, WALL_HEIGHT)
	end

	-- Plinth along the outer foot of the wall (split around the gateway).
	local plinths = if isGate
		then {
			{ -(length + GATE_WIDTH) / 4, (length - GATE_WIDTH) / 2 },
			{ (length + GATE_WIDTH) / 4, (length - GATE_WIDTH) / 2 },
		}
		else { { 0, length } }
	for _, plinth in plinths do
		Builder.part(folder, frame, {
			Name = "WallPlinth",
			Size = Vector3.new(plinth[2], 3, 2),
			At = CFrame.new(plinth[1], 1.5, -(WALL_THICKNESS / 2 + 1)),
			Color = C.DarkStone,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	if isGate then
		-- Keep the gateway clear.
		Builder.part(folder, frame, {
			Name = "GateThreshold",
			Size = Vector3.new(GATE_WIDTH, 0.4, WALL_THICKNESS + 4),
			At = CFrame.new(0, 0.8, -1),
			Color = C.WornStone,
			Material = Enum.Material.Cobblestone,
		})
	end

	-- Battlements on the outer edge, a low parapet on the inner edge.
	for x = -length / 2 + 4, length / 2 - 4, 8 do
		Builder.part(folder, frame, {
			Name = "Merlon",
			Size = Vector3.new(3.5, 4, 2),
			At = CFrame.new(x, WALL_HEIGHT + 2, -(WALL_THICKNESS / 2 - 1)),
			Color = C.Stone,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	Builder.part(folder, frame, {
		Name = "Parapet",
		Size = Vector3.new(length, 1.5, 1),
		At = CFrame.new(0, WALL_HEIGHT + 0.75, WALL_THICKNESS / 2 - 0.5),
		Color = C.Stone,
		Material = Enum.Material.Cobblestone,
		CastShadow = false,
	})
	Builder.neon(
		folder,
		frame,
		Vector3.new(length, 0.4, 0.15),
		CFrame.new(0, WALL_HEIGHT - 3, -(WALL_THICKNESS / 2 + 0.08)),
		C.Cyan
	)

	-- Royal banners on the inner face, facing the town.
	for _, x in { -length / 4, length / 4 } do
		Builder.banner(
			folder,
			frame,
			CFrame.new(x, WALL_HEIGHT - 3, WALL_THICKNESS / 2 + 0.4) * CFrame.Angles(0, math.pi, 0),
			C.Banner,
			12
		)
	end
end

local function tower(folder: Folder, position: Vector3)
	local o = CFrame.new(position)
	local height = WALL_HEIGHT + 10
	Builder.disc(folder, o, {
		Name = "Tower",
		Radius = TOWER_RADIUS,
		Height = height,
		At = CFrame.new(0, height / 2, 0),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.disc(folder, o, {
		Name = "TowerBand",
		Radius = TOWER_RADIUS + 0.15,
		Height = 0.5,
		At = CFrame.new(0, height - 5, 0),
		Color = C.Cyan,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Builder.disc(folder, o, {
		Name = "TowerCrown",
		Radius = TOWER_RADIUS + 1.5,
		Height = 3,
		At = CFrame.new(0, height + 1.5, 0),
		Color = C.Stone,
		Material = Enum.Material.Cobblestone,
	})
	-- Stepped blue roof.
	for i, radius in { TOWER_RADIUS, 8, 5, 2.5 } do
		Builder.disc(folder, o, {
			Name = "TowerRoof",
			Radius = radius,
			Height = 3,
			At = CFrame.new(0, height + 3 + i * 3 - 1.5, 0),
			Color = C.RoofBlue,
			Material = Enum.Material.Slate,
		})
	end
	local top = height + 15
	Builder.part(folder, o, {
		Name = "FlagPole",
		Size = Vector3.new(0.4, 8, 0.4),
		At = CFrame.new(0, top + 4, 0),
		Color = C.Iron,
		Material = Enum.Material.Metal,
		CastShadow = false,
	})
	Builder.part(folder, o, {
		Name = "Flag",
		Size = Vector3.new(4, 2.5, 0.15),
		At = CFrame.new(2.2, top + 6.6, 0),
		Color = C.Banner,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
end

local function gatehouse(folder: Folder, frame: CFrame)
	local towerHeight = WALL_HEIGHT + 12
	for _, side in { -1, 1 } do
		local x = side * (GATE_WIDTH / 2 + 7)
		Builder.part(folder, frame, {
			Name = "GateTower",
			Size = Vector3.new(12, towerHeight, WALL_THICKNESS + 10),
			At = CFrame.new(x, towerHeight / 2, 0),
			Color = C.WornStone,
			Material = Enum.Material.Cobblestone,
		})
		for _, cx in { -4.5, 4.5 } do
			for _, cz in { -7, 7 } do
				Builder.part(folder, frame, {
					Name = "Merlon",
					Size = Vector3.new(3, 3, 3),
					At = CFrame.new(x + cx, towerHeight + 1.5, cz),
					Color = C.WornStone,
					Material = Enum.Material.Cobblestone,
					CastShadow = false,
				})
			end
		end
		-- Big banners either side of the gate, facing out.
		Builder.banner(folder, frame, CFrame.new(x, towerHeight - 4, -(WALL_THICKNESS / 2 + 5.4)), C.Banner, 18)
	end

	-- Raised portcullis teeth and a neon frame around the gateway.
	for x = -GATE_WIDTH / 2 + 2, GATE_WIDTH / 2 - 2, 3 do
		Builder.part(folder, frame, {
			Name = "PortcullisBar",
			Size = Vector3.new(0.6, 3, 0.6),
			At = CFrame.new(x, GATE_HEIGHT - 1.5, -1),
			Color = C.Iron,
			Material = Enum.Material.CorrodedMetal,
			CastShadow = false,
		})
	end
	for _, z in { -(WALL_THICKNESS / 2 + 0.1), WALL_THICKNESS / 2 + 0.1 } do
		Builder.neon(folder, frame, Vector3.new(GATE_WIDTH, 0.5, 0.2), CFrame.new(0, GATE_HEIGHT, z), C.Gold)
	end

	Builder.sign(
		folder,
		frame,
		CFrame.new(0, GATE_HEIGHT + 4, -(WALL_THICKNESS / 2 + 0.35)),
		Vector3.new(20, 3.4, 0.6),
		"GEMSOUL KINGDOM",
		C.Gold
	)
	Builder.sign(
		folder,
		frame,
		CFrame.new(0, GATE_HEIGHT + 4, WALL_THICKNESS / 2 + 0.35) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(20, 3.4, 0.6),
		"SAFE TRAVELS",
		C.Gold
	)

	-- Drawbridge over the moat, with chains back to the gate towers.
	local bridgeLength = Kingdom.MoatDistance - Kingdom.Apothem + 16
	Builder.part(folder, frame, {
		Name = "Drawbridge",
		Size = Vector3.new(GATE_WIDTH - 2, 1, bridgeLength),
		At = CFrame.new(0, 0.6, -(WALL_THICKNESS / 2 + bridgeLength / 2)),
		Color = C.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, side in { -1, 1 } do
		local top = Vector3.new(side * (GATE_WIDTH / 2 - 1), 20, -(WALL_THICKNESS / 2))
		local bottom = Vector3.new(side * (GATE_WIDTH / 2 - 1), 1.2, -(WALL_THICKNESS / 2 + bridgeLength - 1))
		Builder.part(folder, frame, {
			Name = "Chain",
			Size = Vector3.new(0.4, 0.4, (top - bottom).Magnitude),
			At = CFrame.lookAt((top + bottom) / 2, bottom),
			Color = C.Iron,
			Material = Enum.Material.CorrodedMetal,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- True when a spot inside the walls is free of buildings, roads and the plaza.
local function isClear(position: Vector3, margin: number, zones, roadEnds: { [number]: number }): boolean
	local flat = Vector3.new(position.X, 0, position.Z)
	local r = flat.Magnitude
	if r < Hub.PlazaRadius + margin or r > Kingdom.Apothem - WALL_THICKNESS - margin - 6 then
		return false
	end
	for _, zone in zones do
		local footprint = require(zone.Module).Footprint
		local p = zone.Origin:PointToObjectSpace(Vector3.new(position.X, zone.Origin.Y, position.Z))
		if
			p.X > footprint.MinX - margin
			and p.X < footprint.MaxX + margin
			and p.Z > footprint.MinZ - margin
			and p.Z < footprint.MaxZ + margin
		then
			return false
		end
	end
	for angle, roadEnd in roadEnds do
		local p = Hub.radial(angle):PointToObjectSpace(flat)
		if -p.Z > 0 and -p.Z < roadEnd + margin and math.abs(p.X) < 7 + margin then
			return false
		end
	end
	return true
end

local function gardens(folder: Folder, zones, zoneDistance: number)
	local rng = Random.new(42)
	local roadEnds = { [Kingdom.GateAngle] = Kingdom.Apothem }
	for _, zone in zones do
		roadEnds[zone.Angle] = zoneDistance
	end

	local trees = {}
	local function spaced(position: Vector3, gap: number): boolean
		for _, other in trees do
			if (other - position).Magnitude < gap then
				return false
			end
		end
		return true
	end

	-- Tree-lined avenue from the plaza to the main gate.
	local gateFrame = Hub.radial(Kingdom.GateAngle)
	for r = Hub.PlazaRadius + 20, Kingdom.Apothem - 24, 24 do
		for _, side in { -1, 1 } do
			local position = gateFrame * Vector3.new(side * 16, 0.5, -r)
			Builder.tree(folder, position, 1.1, rng)
			table.insert(trees, position)
		end
	end

	-- Trees scattered through the open ground between zones.
	local placed, attempts = 0, 0
	while placed < 45 and attempts < 800 do
		attempts += 1
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = math.sqrt(rng:NextNumber((Hub.PlazaRadius + 10) ^ 2, Kingdom.Apothem ^ 2))
		local position = Vector3.new(r * math.sin(angle), 0.5, -r * math.cos(angle))
		if isClear(position, 7, zones, roadEnds) and spaced(position, 14) then
			Builder.tree(folder, position, rng:NextNumber(0.9, 1.4), rng)
			table.insert(trees, position)
			placed += 1
		end
	end

	-- Flower beds.
	placed, attempts = 0, 0
	while placed < 14 and attempts < 400 do
		attempts += 1
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(Hub.PlazaRadius + 12, Kingdom.Apothem - 30)
		local position = Vector3.new(r * math.sin(angle), 0.5, -r * math.cos(angle))
		if isClear(position, 5, zones, roadEnds) and spaced(position, 9) then
			local at = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			Builder.planter(folder, CFrame.identity, at, 8, rng)
			table.insert(trees, position)
			placed += 1
		end
	end
end

function Kingdom.build(parent: Instance, zones, zoneDistance: number): Folder
	local folder = Builder.folder(parent, "Kingdom")
	local walls = Builder.folder(folder, "Walls")

	for k = 0, SIDES - 1 do
		local a, b = corner(k), corner(k + 1)
		local midAngle = (k + 1) * 360 / SIDES
		-- Frame at the middle of this side, -Z facing out of the kingdom.
		local frame = Hub.radial(midAngle) * CFrame.new(0, 0, -Kingdom.Apothem)
		local isGate = midAngle % 360 == Kingdom.GateAngle
		wallSide(walls, frame, (b - a).Magnitude, isGate)
		tower(walls, a)
		if isGate then
			gatehouse(walls, frame)
		end
	end

	Hub.road(folder, {
		Name = "Gate",
		Title = "MAIN GATE",
		Angle = Kingdom.GateAngle,
		Color = C.Gold,
	}, Kingdom.Apothem - WALL_THICKNESS / 2)

	gardens(Builder.folder(folder, "Gardens"), zones, zoneDistance)
	return folder
end

return Kingdom
