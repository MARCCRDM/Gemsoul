-- Mining Guild and the quarry at the end of the north road.
-- The guild is a stone shopfront with Foreman Garrick outside, a mine cart
-- and the daily quota terminal. The walled quarry holds static gem node
-- spawners, with an energy gate at the back leading to the VIP pit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local QUARRY_HALF_WIDTH = 40
local QUARRY_DEPTH = 55 -- main quarry runs z = 0..55 in the quarry frame
local VIP_HALF_WIDTH = 20
local VIP_DEPTH = 22
local GATE_HALF_WIDTH = 7

local Mining = {}

Mining.QuarryDepth = QUARRY_DEPTH + VIP_DEPTH

local function nodeSpawner(folder: Folder, origin: CFrame, x: number, z: number, isVip: boolean)
	local pad = Builder.disc(folder, origin, {
		Name = "NodeSpawner",
		Radius = 2.2,
		Height = 0.4,
		At = CFrame.new(x, 0.7, z),
		Color = C.Iron,
		Material = Enum.Material.DiamondPlate,
		Tag = Tags.NodeSpawner,
	})
	pad:SetAttribute("VIP", isVip)
	Builder.neonBand(folder, origin, Vector3.new(x, 0.65, z), 2.35, if isVip then C.Magenta else C.Cyan)
end

local function mineCart(folder: Folder, frame: CFrame)
	Builder.part(folder, frame, {
		Name = "MineCart",
		Size = Vector3.new(5, 2.6, 3),
		At = CFrame.new(0, 2.1, 0),
		Color = C.Iron,
		Material = Enum.Material.CorrodedMetal,
	})
	for _, x in { -1.7, 1.7 } do
		for _, z in { -1.6, 1.6 } do
			Builder.part(folder, frame, {
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 1.6, 1.6),
				At = CFrame.new(x, 0.8, z) * CFrame.Angles(0, math.rad(90), 0),
				Color = C.DarkWood,
				Material = Enum.Material.Wood,
				CastShadow = false,
			})
		end
	end
	for i, color in { C.Cyan, C.Magenta, C.Green } do
		Builder.neon(
			folder,
			frame,
			Vector3.new(1, 1.6, 1),
			CFrame.new(-1.5 + (i - 1) * 1.5, 3.6, 0) * CFrame.Angles(0, 0, math.rad(15 * (i - 2))),
			color
		)
	end
end

function Mining.buildGuild(folder: Folder, frame: CFrame, color: Color3)
	Builder.house(folder, frame, {
		Name = "MiningGuild",
		Width = 34,
		Depth = 22,
		Floors = 2,
		Stone = C.DarkStone,
		Roof = C.RoofBlue,
		Trim = color,
	})
	Builder.sign(folder, frame, CFrame.new(0, 8.8, -0.6), Vector3.new(14, 2, 0.5), "MINING GUILD", color)

	-- Foreman Garrick, with the quota terminal beside him.
	Builder.vendor(folder, frame * CFrame.new(5, 0.5, -6), "Mining", Vendors.Mining)
	Builder.part(folder, frame, {
		Name = "TerminalPedestal",
		Size = Vector3.new(3.4, 3, 2.4),
		At = CFrame.new(10, 2, -3),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	local terminal = Builder.screen(folder, frame, CFrame.new(10, 5.3, -3), Vector3.new(4.6, 3.6, 2.4), {
		Name = "QuotaTerminal",
		Text = "FREE MINES\n> PRESS [E]_",
		Tag = Tags.QuotaTerminal,
	})
	Builder.station(terminal, "Mining", "Check Free Mines", "Quota Terminal", "Quota")

	mineCart(folder, frame * CFrame.new(-10, 0.5, -4))
	for i, offset in { Vector3.new(-15, 1.5, -2.5), Vector3.new(-15, 4.5, -2.5), Vector3.new(-12.4, 1.5, -2) } do
		Builder.part(folder, frame, {
			Name = "Crate",
			Size = Vector3.new(3, 3, 3),
			At = CFrame.new(offset) * CFrame.Angles(0, math.rad(i * 12), 0),
			Color = C.Wood,
			Material = Enum.Material.WoodPlanks,
		})
	end
end

function Mining.buildQuarry(folder: Folder, frame: CFrame, color: Color3)
	Builder.landmark("Quarry", (frame * CFrame.new(0, 3, 14)).Position)
	local rng = Random.new(1337)
	local w, vw = QUARRY_HALF_WIDTH, VIP_HALF_WIDTH
	local back = QUARRY_DEPTH + VIP_DEPTH

	-- Rock walls, leaving the entrance and the energy gate open.
	local rock = { Thickness = 3, Color = C.DarkStone, Material = Enum.Material.Rock }
	Builder.wall(folder, frame, -w, 0, -GATE_HALF_WIDTH - 2, 0, 14, rock)
	Builder.wall(folder, frame, GATE_HALF_WIDTH + 2, 0, w, 0, 14, rock)
	Builder.wall(folder, frame, -w, 0, -w, QUARRY_DEPTH, 14, rock)
	Builder.wall(folder, frame, w, 0, w, QUARRY_DEPTH, 14, rock)
	Builder.wall(folder, frame, -w, QUARRY_DEPTH, -GATE_HALF_WIDTH - 2, QUARRY_DEPTH, 14, rock)
	Builder.wall(folder, frame, GATE_HALF_WIDTH + 2, QUARRY_DEPTH, w, QUARRY_DEPTH, 14, rock)
	Builder.wall(folder, frame, -vw, QUARRY_DEPTH, -vw, back, 14, rock)
	Builder.wall(folder, frame, vw, QUARRY_DEPTH, vw, back, 14, rock)
	Builder.wall(folder, frame, -vw, back, vw, back, 14, rock)

	-- Boulders along the inside of the walls for a rugged look.
	local boulders = {}
	for z = 8, QUARRY_DEPTH - 6, 11 do
		table.insert(boulders, Vector3.new(-w + 3, 0, z))
		table.insert(boulders, Vector3.new(w - 3, 0, z))
	end
	for _, x in { -30, -18, 18, 30 } do
		table.insert(boulders, Vector3.new(x, 0, QUARRY_DEPTH - 3))
	end
	for _, z in { QUARRY_DEPTH + 8, back - 6 } do
		table.insert(boulders, Vector3.new(-vw + 3, 0, z))
		table.insert(boulders, Vector3.new(vw - 3, 0, z))
	end
	for _, point in boulders do
		local height = rng:NextNumber(8, 15)
		Builder.rock(
			folder,
			frame,
			point + Vector3.new(0, height / 2 - 1, 0),
			Vector3.new(rng:NextNumber(6, 9), height, rng:NextNumber(6, 9)),
			rng
		)
	end

	-- Entrance arch.
	for _, side in { -1, 1 } do
		Builder.pillar(folder, frame, side * (GATE_HALF_WIDTH + 2), 0, 18, color, {
			Width = 4,
			Color = C.DarkStone,
		})
	end
	Builder.part(folder, frame, {
		Name = "ArchBeam",
		Size = Vector3.new(GATE_HALF_WIDTH * 2 + 8, 2.5, 4),
		At = CFrame.new(0, 19, 0),
		Color = C.DarkStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.sign(folder, frame, CFrame.new(0, 19, -2.3), Vector3.new(12, 2.2, 0.5), "QUARRY", color)

	-- Work lamps and glowing cables.
	for _, side in { -1, 1 } do
		Builder.lamp(folder, frame * CFrame.new(side * (w - 9), 0.5, 6), 0, 0, color, 10)
		Builder.neon(
			folder,
			frame,
			Vector3.new(0.4, 0.4, QUARRY_DEPTH - 12),
			CFrame.new(side * (w - 8), 0.7, QUARRY_DEPTH / 2),
			color
		)
	end

	-- Static node spawners: nodes do not regenerate once mined.
	local spawns = {
		{ -24, 14 },
		{ 0, 12 },
		{ 24, 14 },
		{ -12, 25 },
		{ 12, 25 },
		{ -28, 36 },
		{ 0, 37 },
		{ 28, 36 },
		{ -14, 47 },
		{ 14, 47 },
	}
	for _, spot in spawns do
		nodeSpawner(folder, frame, spot[1], spot[2], false)
	end
	for _, spot in { { -10, 62 }, { 10, 62 }, { -10, 71 }, { 10, 71 } } do
		nodeSpawner(folder, frame, spot[1], spot[2], true)
	end

	-- Energy gate to the VIP pit.
	for _, side in { -1, 1 } do
		Builder.pillar(folder, frame, side * (GATE_HALF_WIDTH + 2), QUARRY_DEPTH, 18, C.Magenta, {
			Width = 4,
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
	end
	Builder.sign(
		folder,
		frame,
		CFrame.new(0, 16.5, QUARRY_DEPTH - 0.5),
		Vector3.new(12, 2, 0.5),
		"VIP // AUTHORIZED",
		C.Magenta
	)
	Builder.part(folder, frame, {
		Name = "EnergyGate",
		Size = Vector3.new(GATE_HALF_WIDTH * 2, 15, 1),
		At = CFrame.new(0, 8, QUARRY_DEPTH),
		Color = C.Magenta,
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
		CastShadow = false,
		Tag = Tags.VipGate,
	})
end

return Mining
