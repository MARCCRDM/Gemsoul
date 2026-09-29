-- Zone 3: Marketplace Building.
-- An open-air bazaar behind a stone arch: two rows of wooden stalls with
-- canvas canopies, each fitted with a digital trading kiosk, drone lanterns
-- over the aisle, and a large holographic board for player trade listings.
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local WIDTH = 70
local DEPTH = 64

local CANOPY_COLORS = {
	Color3.fromRGB(150, 40, 50),
	Color3.fromRGB(30, 110, 110),
	Color3.fromRGB(100, 50, 140),
	Color3.fromRGB(170, 110, 30),
	Color3.fromRGB(40, 90, 150),
	Color3.fromRGB(120, 60, 40),
}

local Marketplace = {}

-- Area the zone occupies in its local space, kept clear of trees and flowers.
Marketplace.Footprint = { MinX = -40, MaxX = 40, MinZ = -4, MaxZ = 68 }

-- A wooden stall whose counter faces the stall frame's -Z (the aisle).
local function stall(folder: Folder, frame: CFrame, index: number, color: Color3)
	Builder.part(folder, frame, {
		Name = "StallCounter",
		Size = Vector3.new(10, 3.5, 3),
		At = CFrame.new(0, 1.75, 0),
		Color = C.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	Builder.part(folder, frame, {
		Name = "StallBackShelf",
		Size = Vector3.new(10, 6, 1.5),
		At = CFrame.new(0, 3, 6),
		Color = C.DarkWood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -4.8, 4.8 } do
		for _, z in { -1, 6 } do
			Builder.part(folder, frame, {
				Name = "StallPost",
				Size = Vector3.new(0.8, 9, 0.8),
				At = CFrame.new(x, 4.5, z),
				Color = C.DarkWood,
				Material = Enum.Material.Wood,
			})
		end
	end
	Builder.part(folder, frame, {
		Name = "Canopy",
		Size = Vector3.new(11, 0.4, 9),
		At = CFrame.new(0, 9.4, 2.5) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = CANOPY_COLORS[(index - 1) % #CANOPY_COLORS + 1],
		Material = Enum.Material.Fabric,
	})
	-- Neon price strip along the counter front.
	Builder.neon(folder, frame, Vector3.new(10.2, 0.3, 0.2), CFrame.new(0, 3.2, -1.55), color)

	local kiosk = Builder.screen(folder, frame, CFrame.new(2.5, 4.8, 0), Vector3.new(3.4, 2.6, 2), {
		Name = "TradeKiosk",
		Text = string.format("KIOSK %02d\n> TRADE [E]_", index),
		Tag = Tags.TradeKiosk,
	})
	kiosk:SetAttribute("KioskId", index)
	Builder.prompt(kiosk, "Open Kiosk", string.format("Trade Kiosk %02d", index))

	-- Crates of goods.
	Builder.part(folder, frame, {
		Name = "Crate",
		Size = Vector3.new(2, 2, 2),
		At = CFrame.new(-3, 4.5, 0) * CFrame.Angles(0, math.rad(15), 0),
		Color = C.Wood,
		Material = Enum.Material.Wood,
	})
end

local function tradeBoard(folder: Folder, origin: CFrame, color: Color3)
	local z = DEPTH - 8
	for _, x in { -10, 10 } do
		Builder.part(folder, origin, {
			Name = "BoardPost",
			Size = Vector3.new(1.4, 22, 1.4),
			At = CFrame.new(x, 11, z),
			Color = C.Chrome,
			Material = Enum.Material.Metal,
		})
		Builder.neon(folder, origin, Vector3.new(1.6, 0.3, 1.6), CFrame.new(x, 20, z), color)
	end
	Builder.part(folder, origin, {
		Name = "BoardBase",
		Size = Vector3.new(24, 1.5, 4),
		At = CFrame.new(0, 0.75, z),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.holo(
		folder,
		origin,
		CFrame.new(0, 13, z),
		Vector3.new(18, 12, 0.3),
		color,
		"P2P TRADE LISTINGS\n\n-- NO LISTINGS YET --",
		Tags.TradeBoard
	)
end

function Marketplace.build(folder: Folder, origin: CFrame, color: Color3)
	Builder.part(folder, origin, {
		Name = "BazaarFloor",
		Size = Vector3.new(WIDTH, 1, DEPTH),
		At = CFrame.new(0, -0.4, DEPTH / 2),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	-- Aisle runner.
	Builder.part(folder, origin, {
		Name = "Aisle",
		Size = Vector3.new(10, 0.2, DEPTH - 12),
		At = CFrame.new(0, 0.2, (DEPTH - 12) / 2),
		Color = C.Stone,
		Material = Enum.Material.Slate,
	})

	-- Low perimeter walls and a grand entrance arch.
	local hw = WIDTH / 2
	local low = { Thickness = 2, Color = C.Stone, Battlements = true, Trim = color }
	Builder.wall(folder, origin, -hw, 0, -8, 0, 4, low)
	Builder.wall(folder, origin, 8, 0, hw, 0, 4, low)
	Builder.wall(folder, origin, -hw, DEPTH, hw, DEPTH, 4, low)
	Builder.wall(folder, origin, -hw, 0, -hw, DEPTH, 4, low)
	Builder.wall(folder, origin, hw, 0, hw, DEPTH, 4, low)
	for _, side in { -1, 1 } do
		Builder.pillar(folder, origin, side * 9, 0, 18, color, { Width = 4 })
		for _, z in { 3, DEPTH - 3 } do
			Builder.lamp(folder, origin * CFrame.new(side * (hw - 2), 0, z), 0, 0, C.Amber, 10)
		end
	end
	Builder.part(folder, origin, {
		Name = "ArchBeam",
		Size = Vector3.new(24, 3, 4),
		At = CFrame.new(0, 19.5, 0),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.sign(folder, origin, CFrame.new(0, 19.5, -2.3), Vector3.new(16, 2.6, 0.5), "BAZAAR // EXCHANGE", color)

	-- Two rows of stalls facing the centre aisle.
	local index = 0
	for _, z in { 14, 28, 42 } do
		for _, side in { -1, 1 } do
			index += 1
			-- Rotate so the counter (-Z) faces the aisle at x = 0.
			local frame = origin * CFrame.new(side * 20, 0, z) * CFrame.Angles(0, math.rad(side * 90), 0)
			stall(folder, frame, index, color)
		end
	end

	-- Hovering drone lanterns over the aisle.
	for _, z in { 10, 22, 34, 46 } do
		local lantern =
			Builder.neon(folder, origin, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 11, z), color, nil, Tags.Bob)
		lantern.Name = "DroneLantern"
	end

	tradeBoard(folder, origin, color)
end

return Marketplace
