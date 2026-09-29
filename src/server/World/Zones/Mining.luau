-- Zone 1: Mining Building / Introduction Zone.
-- A stone gatehouse opening onto a rugged, neon-lit quarry. Static gem node
-- spawners dot the floor and ledges, a CRT terminal checks the daily quota,
-- and an energy gate at the back leads to the VIP quarry.
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local WIDTH = 100
local QUARRY_DEPTH = 100 -- main quarry runs z = 0..100
local VIP_DEPTH = 32 -- VIP quarry behind the energy gate
local GATE_WIDTH = 16

local Mining = {}

-- Area the zone occupies in its local space, kept clear of trees and flowers.
Mining.Footprint = { MinX = -64, MaxX = 64, MinZ = -4, MaxZ = 146 }

local function nodeSpawner(folder: Folder, origin: CFrame, x: number, y: number, z: number, isVip: boolean)
	local color = if isVip then C.Magenta else C.Cyan
	local pad = Builder.disc(folder, origin, {
		Name = "NodeSpawner",
		Radius = 2.2,
		Height = 0.4,
		At = CFrame.new(x, y + 0.2, z),
		Color = C.Iron,
		Material = Enum.Material.DiamondPlate,
		Tag = Tags.NodeSpawner,
	})
	pad:SetAttribute("VIP", isVip)
	Builder.neonBand(folder, origin, Vector3.new(x, y + 0.15, z), 2.35, color)
end

local function ledge(folder: Folder, origin: CFrame, x: number, z1: number, z2: number, height: number)
	local depth = z2 - z1
	Builder.part(folder, origin, {
		Name = "Ledge",
		Size = Vector3.new(16, height, depth),
		At = CFrame.new(x, height / 2, (z1 + z2) / 2),
		Color = C.DarkStone,
		Material = Enum.Material.Rock,
	})
	-- Ramp up from the quarry floor at the near end.
	Builder.part(folder, origin, {
		Class = "WedgePart",
		Name = "Ramp",
		Size = Vector3.new(8, height, 10),
		At = CFrame.new(x, height / 2, z1 - 5),
		Color = C.DarkStone,
		Material = Enum.Material.Rock,
	})
	Builder.neon(folder, origin, Vector3.new(16, 0.2, 0.4), CFrame.new(x, height + 0.05, z1 + 0.3), C.Cyan)
end

local function cliffLine(folder: Folder, origin: CFrame, rng: Random, points: { Vector3 })
	for _, point in points do
		local height = rng:NextNumber(16, 28)
		Builder.rock(
			folder,
			origin,
			point + Vector3.new(0, height / 2 - 2, 0),
			Vector3.new(rng:NextNumber(10, 16), height, rng:NextNumber(10, 16)),
			rng
		)
	end
end

local function gatehouse(folder: Folder, origin: CFrame)
	Builder.wallWithDoor(folder, origin, -WIDTH / 2 + 4, 0, WIDTH / 2 - 4, 0, 18, 14, 12, {
		Thickness = 4,
		Color = C.DarkStone,
		Battlements = true,
		Trim = C.Cyan,
	})
	for _, side in { -1, 1 } do
		Builder.pillar(folder, origin, side * (WIDTH / 2), 0, 26, C.Cyan, {
			Width = 9,
			Color = C.DarkStone,
		})
		Builder.torch(folder, origin, CFrame.new(side * 10, 8, -2.6), C.Cyan)
	end
	Builder.sign(folder, origin, CFrame.new(0, 15, -2.3), Vector3.new(18, 3.4, 0.6), "MINE // SECTOR 01", C.Cyan)
end

local function quotaTerminal(folder: Folder, origin: CFrame)
	local x, z = -14, 14
	Builder.part(folder, origin, {
		Name = "TerminalDesk",
		Size = Vector3.new(7, 3, 4),
		At = CFrame.new(x, 1.5, z),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	local monitor = Builder.screen(folder, origin, CFrame.new(x, 5.4, z), Vector3.new(6, 4.8, 3), {
		Name = "QuotaTerminal",
		Text = "DAILY QUOTA\n> PRESS [E]_",
		Tag = Tags.QuotaTerminal,
	})
	Builder.prompt(monitor, "Check Quota", "Quota Terminal")
	Builder.neon(folder, origin, Vector3.new(7.2, 0.3, 4.2), CFrame.new(x, 3.05, z), C.Cyan)
end

local function energyGate(folder: Folder, origin: CFrame)
	local z = QUARRY_DEPTH
	for _, side in { -1, 1 } do
		Builder.pillar(folder, origin, side * (GATE_WIDTH / 2 + 2), z, 22, C.Magenta, {
			Width = 4,
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
		-- Emitter coils facing the field.
		for _, y in { 4, 10, 16 } do
			Builder.part(folder, origin, {
				Name = "GateCoil",
				Size = Vector3.new(1, 1.2, 1.2),
				At = CFrame.new(side * (GATE_WIDTH / 2 - 0.4), y, z),
				Color = C.Chrome,
				Material = Enum.Material.Metal,
			})
		end
	end
	Builder.part(folder, origin, {
		Name = "GateLintel",
		Size = Vector3.new(GATE_WIDTH + 8, 3, 4),
		At = CFrame.new(0, 23.5, z),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.sign(
		folder,
		origin,
		CFrame.new(0, 23.5, z - 2.3),
		Vector3.new(16, 2.4, 0.5),
		"VIP // AUTHORIZED",
		C.Magenta
	)

	Builder.part(folder, origin, {
		Name = "EnergyGate",
		Size = Vector3.new(GATE_WIDTH, 22, 1),
		At = CFrame.new(0, 11, z),
		Color = C.Magenta,
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
		CastShadow = false,
		Tag = Tags.VipGate,
	})
end

function Mining.build(folder: Folder, origin: CFrame)
	local rng = Random.new(1337)
	local totalDepth = QUARRY_DEPTH + VIP_DEPTH

	Builder.part(folder, origin, {
		Name = "QuarryFloor",
		Size = Vector3.new(WIDTH, 1, totalDepth),
		At = CFrame.new(0, -0.4, totalDepth / 2),
		Color = C.DarkStone,
		Material = Enum.Material.Ground,
	})
	-- VIP floor: glowing magenta grid.
	for x = -12, 12, 6 do
		Builder.neon(
			folder,
			origin,
			Vector3.new(0.3, 0.1, VIP_DEPTH - 2),
			CFrame.new(x, 0.15, QUARRY_DEPTH + VIP_DEPTH / 2),
			C.Magenta
		)
	end

	gatehouse(folder, origin)

	-- Rugged cliff walls around the quarry, leaving a gap for the energy gate.
	local cliff = {}
	for z = 8, QUARRY_DEPTH, 11 do
		table.insert(cliff, Vector3.new(-WIDTH / 2 - 2, 0, z))
		table.insert(cliff, Vector3.new(WIDTH / 2 + 2, 0, z))
	end
	for x = -WIDTH / 2 + 6, WIDTH / 2 - 6, 11 do
		if math.abs(x) > GATE_WIDTH / 2 + 8 then
			table.insert(cliff, Vector3.new(x, 0, QUARRY_DEPTH + 2))
		end
	end
	-- VIP quarry walls.
	for z = QUARRY_DEPTH + 8, totalDepth, 10 do
		table.insert(cliff, Vector3.new(-24, 0, z))
		table.insert(cliff, Vector3.new(24, 0, z))
	end
	for x = -18, 18, 12 do
		table.insert(cliff, Vector3.new(x, 0, totalDepth + 4))
	end
	cliffLine(folder, origin, rng, cliff)

	-- Solid walls behind the rocks so nobody can slip around the energy gate.
	local wallProps = { Thickness = 3, Color = C.DarkStone, Material = Enum.Material.Rock }
	Builder.wall(folder, origin, -WIDTH / 2, 2, -WIDTH / 2, QUARRY_DEPTH, 16, wallProps)
	Builder.wall(folder, origin, WIDTH / 2, 2, WIDTH / 2, QUARRY_DEPTH, 16, wallProps)
	Builder.wall(folder, origin, -WIDTH / 2, QUARRY_DEPTH, -GATE_WIDTH / 2 - 2, QUARRY_DEPTH, 16, wallProps)
	Builder.wall(folder, origin, GATE_WIDTH / 2 + 2, QUARRY_DEPTH, WIDTH / 2, QUARRY_DEPTH, 16, wallProps)
	Builder.wall(folder, origin, -22, QUARRY_DEPTH, -22, totalDepth, 16, wallProps)
	Builder.wall(folder, origin, 22, QUARRY_DEPTH, 22, totalDepth, 16, wallProps)
	Builder.wall(folder, origin, -22, totalDepth, 22, totalDepth, 16, wallProps)

	-- Neon cables and work lights embedded in the rock.
	for _, side in { -1, 1 } do
		local x = side * (WIDTH / 2 - 7)
		Builder.neon(
			folder,
			origin,
			Vector3.new(0.4, 0.4, QUARRY_DEPTH - 10),
			CFrame.new(x, 0.3, QUARRY_DEPTH / 2 + 5),
			C.Cyan
		)
		for _, z in { 18, 92 } do
			Builder.lamp(folder, origin * CFrame.new(x, 0, z), 0, 0, C.Cyan, 10)
		end
	end

	ledge(folder, origin, -34, 40, 80, 5)
	ledge(folder, origin, 34, 40, 80, 5)

	-- Static node spawners (nodes do not regenerate once mined).
	local floorSpawns = {
		{ -16, 30 },
		{ 0, 36 },
		{ 16, 30 },
		{ -10, 55 },
		{ 10, 55 },
		{ 0, 72 },
		{ -18, 86 },
		{ 18, 86 },
	}
	for _, spot in floorSpawns do
		nodeSpawner(folder, origin, spot[1], 0.1, spot[2], false)
	end
	for _, spot in { { -34, 50 }, { -34, 70 }, { 34, 50 }, { 34, 70 } } do
		nodeSpawner(folder, origin, spot[1], 5, spot[2], false)
	end
	for _, spot in { { -10, 112 }, { 10, 112 }, { -10, 124 }, { 10, 124 } } do
		nodeSpawner(folder, origin, spot[1], 0.1, spot[2], true)
	end

	quotaTerminal(folder, origin)
	energyGate(folder, origin)
end

return Mining
