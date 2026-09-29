-- Marketplace: wooden stalls with digital trading kiosks around the edges of
-- the town square, drone lanterns overhead, and the holographic trade board
-- where Tamsin the broker takes player-to-player listings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local CANOPY_COLORS = {
	Color3.fromRGB(150, 40, 50),
	Color3.fromRGB(30, 110, 110),
	Color3.fromRGB(100, 50, 140),
	Color3.fromRGB(170, 110, 30),
	Color3.fromRGB(40, 90, 150),
	Color3.fromRGB(120, 60, 40),
}

local Marketplace = {}

-- A wooden stall whose counter faces the frame's -Z.
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
		At = CFrame.new(0, 3, 5),
		Color = C.DarkWood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -4.8, 4.8 } do
		for _, z in { -1, 5 } do
			Builder.part(folder, frame, {
				Name = "StallPost",
				Size = Vector3.new(0.8, 9, 0.8),
				At = CFrame.new(x, 4.5, z),
				Color = C.DarkWood,
				Material = Enum.Material.Wood,
				CastShadow = false,
			})
		end
	end
	Builder.part(folder, frame, {
		Name = "Canopy",
		Size = Vector3.new(11, 0.4, 8),
		At = CFrame.new(0, 9.4, 2) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = CANOPY_COLORS[(index - 1) % #CANOPY_COLORS + 1],
		Material = Enum.Material.Fabric,
	})
	Builder.neon(folder, frame, Vector3.new(10.2, 0.3, 0.2), CFrame.new(0, 3.2, -1.55), color)
	Builder.screen(folder, frame, CFrame.new(2.5, 4.8, 0), Vector3.new(3.4, 2.6, 2), {
		Name = "TradeKiosk",
		Text = string.format("KIOSK %02d\n> ONLINE_", index),
		Tag = Tags.TradeKiosk,
	})
	Builder.part(folder, frame, {
		Name = "Crate",
		Size = Vector3.new(2, 2, 2),
		At = CFrame.new(-3, 4.5, 0) * CFrame.Angles(0, math.rad(15), 0),
		Color = C.Wood,
		Material = Enum.Material.Wood,
	})
end

local function tradeBoard(folder: Folder, frame: CFrame, color: Color3)
	for _, x in { -8, 8 } do
		Builder.part(folder, frame, {
			Name = "BoardPost",
			Size = Vector3.new(1.2, 18, 1.2),
			At = CFrame.new(x, 9, 0),
			Color = C.Chrome,
			Material = Enum.Material.Metal,
		})
		Builder.neon(folder, frame, Vector3.new(1.4, 0.3, 1.4), CFrame.new(x, 16.5, 0), color)
	end
	Builder.part(folder, frame, {
		Name = "BoardBase",
		Size = Vector3.new(19, 1.2, 3),
		At = CFrame.new(0, 0.6, 0),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	local base = Builder.part(folder, frame, {
		Name = "BoardConsole",
		Size = Vector3.new(4, 3.4, 2),
		At = CFrame.new(0, 2.9, -0.6),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	Builder.station(base, "Market", "View Listings", "Trade Board")
	Builder.holo(
		folder,
		frame,
		CFrame.new(0, 10.5, 0),
		Vector3.new(14.5, 9, 0.3),
		color,
		"P2P TRADE LISTINGS\n\n-- NO LISTINGS YET --",
		Tags.TradeBoard
	)
end

-- `square` is the square's centre on the ground; stalls sit `edge` studs out.
function Marketplace.build(folder: Folder, square: CFrame, color: Color3, edge: number)
	local stalls = {
		-- position (x, z) and the direction the counter faces
		{ -edge, -22, 1, 0 },
		{ -edge, 22, 1, 0 },
		{ edge, 22, -1, 0 },
		{ -22, edge, 0, -1 },
		{ 22, edge, 0, -1 },
		{ -22, -edge, 0, 1 },
	}
	for i, s in stalls do
		stall(folder, Builder.facing(square * Vector3.new(s[1], 0, s[2]), s[3], s[4]), i, color)
	end

	local board = Builder.facing(square * Vector3.new(edge + 1, 0, -22), -1, 0)
	tradeBoard(folder, board, color)
	Builder.vendor(folder, board * CFrame.new(3, 0, -5), "Market", Vendors.Market)

	for _, angle in { 0, 90, 180, 270 } do
		local position = square * (CFrame.Angles(0, math.rad(angle + 45), 0) * Vector3.new(0, 12, -22))
		local lantern = Builder.neon(
			folder,
			CFrame.new(position),
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.identity,
			color,
			nil,
			Tags.Bob
		)
		lantern.Name = "DroneLantern"
	end
end

return Marketplace
