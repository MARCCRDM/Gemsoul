--[[
	Drawn UI art for the Supply Depot and the crate reveal, built from frames
	so it matches the station look (no emoji):
	  ShopArt.crate(parent, size, glow)            a supply cache pod with a
	                                                glowing core and crystals
	  ShopArt.icon(parent, kind, cosmetic?, size)  what a reward looks like
	  ShopArt.rarityTile(parent, rarity, size)     a dark tile edged in a
	                                                rarity colour
	  ShopArt.coin(parent, size)                    the coin used on prices
	Everything returned is anchored at its centre; callers set Position.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local IronUi = require(script.Parent.IronUi)

local new = IronUi.new
local P = IronUi.Colors
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local ShopArt = {}

-- Emoji kept for older screens that still draw text icons (the mine's loot list).
ShopArt.KindIcons =
	{ Stones = "⛏️", Materials = "⚒️", Marks = "🎖️", CutGems = "💎", Coins = "💰", Cosmetic = "✨" }
ShopArt.MaterialIcons =
	{ Iron = "⛓️", Timber = "🌲", Leather = "🥾", Cloth = "🧵", Mithril = "💠", Shards = "✨" }
ShopArt.KindColors = {
	Coins = P.Gold,
	Marks = Color3.fromRGB(90, 150, 240),
	Stones = Color3.fromRGB(150, 205, 235),
	CutGems = Color3.fromRGB(190, 110, 255),
	Materials = Color3.fromRGB(170, 180, 195),
	Crates = Color3.fromRGB(80, 200, 230),
	Cosmetic = Color3.fromRGB(240, 110, 200),
	XPBoost = P.Emerald,
}

local function round(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 }, parent)
end

-- A frame placed by fractions of its parent, centred on (x, y).
local function piece(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, rotation: number?)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		Rotation = rotation or 0,
	}, parent)
end

local function canvas(parent: Instance, size: number, name: string?): Frame
	return new("Frame", {
		Name = name or "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
	}, parent)
end

-- A faceted gem: a diamond with a light upper facet.
local function gem(parent: Instance, x: number, y: number, w: number, color: Color3, size: number)
	local body = piece(parent, x, y, w, w, WHITE, 45)
	round(body, math.max(2, math.floor(size * w * 0.08)))
	gradient(body, color:Lerp(WHITE, 0.55), color:Lerp(BLACK, 0.25), 45)
	stroke(body, color:Lerp(WHITE, 0.7), math.max(1, size / 60), 0.1)
	local facet = piece(body, 0.32, 0.32, 0.42, 0.42, WHITE)
	facet.BackgroundTransparency = 0.45
	round(facet, 2)
	return body
end

-- Coin ----------------------------------------------------------------------------------------------

function ShopArt.coin(parent: Instance, size: number): Frame
	local root = canvas(parent, size, "Coin")
	local disc = piece(root, 0.5, 0.5, 0.92, 0.92, WHITE)
	round(disc, size)
	gradient(disc, Color3.fromRGB(255, 232, 140), Color3.fromRGB(214, 140, 36))
	stroke(disc, Color3.fromRGB(120, 72, 18), math.max(1, size / 14))
	local inner = piece(disc, 0.5, 0.5, 0.62, 0.62, WHITE)
	inner.BackgroundTransparency = 1
	round(inner, size)
	stroke(inner, Color3.fromRGB(255, 246, 200), math.max(1, size / 22), 0.35)
	local mark = piece(disc, 0.5, 0.5, 0.3, 0.3, Color3.fromRGB(255, 250, 220), 45)
	round(mark, 1)
	return root
end

-- The cache pod --------------------------------------------------------------------------------------

-- A sealed station supply cache: plated hull, glowing core and light strips,
-- with raw crystals breaking through the lid.
function ShopArt.crate(parent: Instance, size: number, glow: Color3?): Frame
	local color = glow or Color3.fromRGB(90, 230, 255)
	local root = canvas(parent, size, "Crate")
	local edge = math.max(1.5, size / 70)
	-- Soft glow and a floor shadow.
	local halo = piece(root, 0.5, 0.55, 1.02, 1.02, color)
	halo.BackgroundTransparency = 0.84
	round(halo, size)
	local shadow = piece(root, 0.5, 0.96, 0.7, 0.07, BLACK)
	shadow.BackgroundTransparency = 0.55
	round(shadow, size)
	-- Crystals behind the lid.
	for _, spec in { { 0.38, -20, 0.1, 0.16 }, { 0.5, 4, 0.12, 0.22 }, { 0.63, 22, 0.09, 0.14 } } do
		local shard = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(spec[1], 0.3),
			Size = UDim2.fromScale(spec[3], spec[4]),
			Rotation = spec[2],
			BackgroundColor3 = WHITE,
		}, root)
		round(shard, math.max(2, math.floor(size * 0.02)))
		gradient(shard, color:Lerp(WHITE, 0.65), color)
		stroke(shard, color:Lerp(WHITE, 0.8), math.max(1, size / 120), 0.3)
	end
	-- Hull.
	local hull = piece(root, 0.5, 0.64, 0.78, 0.5, WHITE)
	round(hull, math.floor(size * 0.07))
	gradient(hull, Color3.fromRGB(104, 118, 142), Color3.fromRGB(34, 38, 56))
	stroke(hull, P.Ink, edge)
	-- Plate seams.
	for _, y in { 0.33, 0.7 } do
		local seam = piece(hull, 0.5, y, 0.9, 0.025, BLACK)
		seam.BackgroundTransparency = 0.55
	end
	-- Light strips down each side.
	for _, x in { 0.13, 0.87 } do
		local strip = piece(hull, x, 0.52, 0.05, 0.62, color)
		round(strip, 3)
		gradient(strip, color:Lerp(WHITE, 0.5), color)
	end
	-- Lid.
	local lid = piece(root, 0.5, 0.36, 0.88, 0.16, WHITE)
	round(lid, math.floor(size * 0.05))
	gradient(lid, Color3.fromRGB(150, 164, 188), Color3.fromRGB(66, 74, 96))
	stroke(lid, P.Ink, edge)
	local lip = piece(lid, 0.5, 0.2, 0.86, 0.12, WHITE)
	lip.BackgroundTransparency = 0.6
	round(lip, 2)
	-- Hazard ticks on the lid.
	for i = 0, 2 do
		local tick = piece(lid, 0.78 + i * 0.06, 0.6, 0.025, 0.42, P.Gold, 25)
		tick.BackgroundTransparency = 0.15
	end
	-- Core: a ring with the gem inside.
	local ring = piece(root, 0.5, 0.66, 0.34, 0.34, Color3.fromRGB(16, 20, 34))
	round(ring, size)
	stroke(ring, color, math.max(2, size / 50), 0.1)
	local glowCore = piece(ring, 0.5, 0.5, 0.86, 0.86, color)
	glowCore.BackgroundTransparency = 0.7
	round(glowCore, size)
	gem(root, 0.5, 0.66, 0.17, color, size)
	-- Feet.
	for _, x in { 0.24, 0.76 } do
		local foot = piece(root, x, 0.905, 0.12, 0.05, Color3.fromRGB(30, 34, 48))
		round(foot, 2)
		stroke(foot, P.Ink, edge * 0.7)
	end
	return root
end

-- Reward icons --------------------------------------------------------------------------------------

local function sparkle(root: Frame, color: Color3, x: number, y: number, s: number)
	for _, rotation in { 0, 90 } do
		local ray = piece(root, x, y, s * 0.18, s, color, rotation)
		round(ray, 4)
		gradient(ray, WHITE, color, 0)
	end
	for _, rotation in { 45, -45 } do
		local ray = piece(root, x, y, s * 0.12, s * 0.55, color, rotation)
		round(ray, 3)
		ray.BackgroundTransparency = 0.2
	end
	local core = piece(root, x, y, s * 0.24, s * 0.24, WHITE)
	round(core, 99)
end

local DRAW = {}

function DRAW.Coins(root: Frame, size: number)
	-- A small stack behind one big coin.
	local back = ShopArt.coin(root, size * 0.62)
	back.Position = UDim2.fromScale(0.66, 0.38)
	local front = ShopArt.coin(root, size * 0.74)
	front.Position = UDim2.fromScale(0.44, 0.56)
end

function DRAW.CutGems(root: Frame, size: number)
	gem(root, 0.5, 0.52, 0.5, ShopArt.KindColors.CutGems, size)
	sparkle(root, WHITE, 0.78, 0.22, 0.26)
end

function DRAW.Stones(root: Frame, size: number)
	gem(root, 0.36, 0.6, 0.36, Color3.fromRGB(120, 230, 200), size)
	gem(root, 0.62, 0.44, 0.42, ShopArt.KindColors.Stones, size)
end

function DRAW.Marks(root: Frame, size: number)
	for _, x in { 0.4, 0.6 } do
		local tail = piece(root, x, 0.74, 0.14, 0.34, Color3.fromRGB(200, 60, 70), if x < 0.5 then 12 else -12)
		round(tail, 2)
	end
	local medal = piece(root, 0.5, 0.42, 0.56, 0.56, WHITE)
	round(medal, size)
	gradient(medal, Color3.fromRGB(150, 200, 255), ShopArt.KindColors.Marks)
	stroke(medal, P.Ink, math.max(1.5, size / 40))
	local star = piece(medal, 0.5, 0.5, 0.36, 0.36, WHITE, 45)
	round(star, 2)
end

function DRAW.Materials(root: Frame, size: number)
	for i, y in { 0.66, 0.46 } do
		local ingot = piece(root, 0.5 + (i - 1.5) * 0.08, y, 0.62, 0.2, WHITE)
		round(ingot, math.max(2, math.floor(size * 0.04)))
		gradient(ingot, Color3.fromRGB(230, 236, 245), ShopArt.KindColors.Materials:Lerp(BLACK, 0.3))
		stroke(ingot, P.Ink, math.max(1, size / 50))
	end
end

function DRAW.Crates(root: Frame, size: number)
	ShopArt.crate(root, size, ShopArt.KindColors.Crates)
end

function DRAW.XPBoost(root: Frame, size: number)
	local disc = piece(root, 0.5, 0.5, 0.84, 0.84, WHITE)
	round(disc, size)
	gradient(disc, P.Emerald:Lerp(WHITE, 0.25), P.Emerald:Lerp(BLACK, 0.45))
	stroke(disc, P.Ink, math.max(1.5, size / 40))
	for _, y in { 0.4, 0.62 } do
		for _, side in { -1, 1 } do
			local arm = piece(disc, 0.5 + side * 0.11, y, 0.08, 0.3, WHITE, -side * 45)
			round(arm, 2)
		end
	end
end

-- A cosmetic of unknown look (crate odds): a rarity sparkle.
function DRAW.Cosmetic(root: Frame, _size: number)
	sparkle(root, ShopArt.KindColors.Cosmetic, 0.5, 0.5, 0.86)
end

-- Back pieces, by Look.
local BACKS = {}

function BACKS.Pack(root: Frame, size: number, color: Color3)
	local bag = piece(root, 0.5, 0.56, 0.6, 0.66, WHITE)
	round(bag, math.floor(size * 0.1))
	gradient(bag, Color3.fromRGB(150, 160, 178), Color3.fromRGB(58, 64, 84))
	stroke(bag, P.Ink, math.max(1.5, size / 45))
	local flap = piece(bag, 0.5, 0.2, 1.04, 0.36, WHITE)
	round(flap, math.floor(size * 0.08))
	gradient(flap, Color3.fromRGB(180, 190, 206), Color3.fromRGB(96, 104, 126))
	stroke(flap, P.Ink, math.max(1, size / 60))
	local light = piece(bag, 0.5, 0.66, 0.3, 0.08, color)
	round(light, 3)
	for _, x in { 0.22, 0.78 } do
		local strap = piece(bag, x, 0.62, 0.08, 0.5, Color3.fromRGB(36, 40, 56))
		round(strap, 2)
	end
end

function BACKS.Banner(root: Frame, _size: number, color: Color3)
	local pole = piece(root, 0.3, 0.5, 0.05, 0.86, WHITE)
	round(pole, 2)
	gradient(pole, Color3.fromRGB(230, 236, 245), Color3.fromRGB(110, 118, 140), 0)
	local cap = piece(root, 0.3, 0.08, 0.1, 0.1, P.Gold, 45)
	round(cap, 2)
	-- The flag with two swallowtail points.
	for _, x in { 0.44, 0.66 } do
		local tip = piece(root, x, 0.62, 0.16, 0.16, color:Lerp(BLACK, 0.15), 45)
		round(tip, 1)
	end
	local flag = piece(root, 0.55, 0.38, 0.44, 0.46, WHITE)
	round(flag, 3)
	gradient(flag, color:Lerp(WHITE, 0.25), color:Lerp(BLACK, 0.2))
	local emblem = piece(flag, 0.5, 0.48, 0.34, 0.3, WHITE, 45)
	emblem.BackgroundTransparency = 0.25
	round(emblem, 2)
end

-- The Crusader's Standard: black and gold, whatever its glow.
function BACKS.Standard(root: Frame, _size: number, color: Color3)
	local pole = piece(root, 0.26, 0.52, 0.05, 0.9, Color3.fromRGB(96, 100, 112))
	round(pole, 2)
	local tip = piece(root, 0.26, 0.06, 0.09, 0.09, P.Gold, 45)
	round(tip, 1)
	local bar = piece(root, 0.52, 0.16, 0.56, 0.04, P.Gold)
	round(bar, 2)
	local flag = piece(root, 0.52, 0.44, 0.48, 0.5, Color3.fromRGB(20, 20, 24))
	round(flag, 2)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = P.Gold, 2
	edge.Parent = flag
	for _, x in { 0.39, 0.65 } do
		local tail = piece(root, x, 0.72, 0.18, 0.18, Color3.fromRGB(20, 20, 24), 45)
		round(tail, 1)
	end
	local emblem = piece(flag, 0.5, 0.48, 0.32, 0.26, color, 45)
	round(emblem, 2)
end

function BACKS.Geode(root: Frame, size: number, color: Color3)
	local shell = piece(root, 0.5, 0.52, 0.8, 0.8, WHITE)
	round(shell, size)
	gradient(shell, Color3.fromRGB(128, 120, 132), Color3.fromRGB(52, 48, 58))
	stroke(shell, P.Ink, math.max(1.5, size / 45))
	local cavity = piece(shell, 0.5, 0.5, 0.7, 0.7, color:Lerp(BLACK, 0.55))
	round(cavity, size)
	for _, spec in { { 0.36, 0.56, 0.24 }, { 0.6, 0.42, 0.3 }, { 0.58, 0.68, 0.2 } } do
		gem(cavity, spec[1], spec[2], spec[3], color, size)
	end
end

function BACKS.Cape(root: Frame, size: number, color: Color3)
	local cloth = piece(root, 0.5, 0.56, 0.6, 0.76, WHITE)
	round(cloth, math.floor(size * 0.08))
	gradient(cloth, color:Lerp(BLACK, 0.15), color:Lerp(BLACK, 0.6))
	stroke(cloth, P.Ink, math.max(1.5, size / 45))
	local hem = piece(cloth, 0.5, 0.92, 0.9, 0.08, color:Lerp(WHITE, 0.35))
	round(hem, 3)
	for _, x in { 0.35, 0.65 } do
		local fold = piece(cloth, x, 0.55, 0.04, 0.7, BLACK)
		fold.BackgroundTransparency = 0.65
	end
	local collar = piece(root, 0.5, 0.18, 0.7, 0.1, WHITE)
	round(collar, 4)
	gradient(collar, Color3.fromRGB(220, 226, 238), Color3.fromRGB(110, 118, 140))
	stroke(collar, P.Ink, math.max(1, size / 60))
	for _, x in { 0.2, 0.8 } do
		local clasp = piece(root, x, 0.18, 0.1, 0.1, P.Gold, 45)
		round(clasp, 2)
	end
end

function BACKS.Wings(root: Frame, size: number, color: Color3)
	for _, side in { -1, 1 } do
		for i, spec in { { 0.3, 0.42, 0.24, 0.6, 32 }, { 0.22, 0.6, 0.18, 0.44, 52 } } do
			local feather = piece(root, 0.5 + side * spec[1], spec[2], spec[3], spec[4], WHITE, side * spec[5])
			round(feather, size)
			gradient(feather, WHITE:Lerp(color, 0.3), color:Lerp(BLACK, 0.2 + i * 0.1))
			stroke(feather, color:Lerp(WHITE, 0.6), math.max(1, size / 70), 0.2)
		end
	end
	local core = piece(root, 0.5, 0.5, 0.12, 0.12, WHITE, 45)
	round(core, 2)
end

function BACKS.Halo(root: Frame, size: number, color: Color3)
	local glow = piece(root, 0.5, 0.5, 0.86, 0.3, color)
	glow.BackgroundTransparency = 0.88
	round(glow, size)
	local ring = piece(root, 0.5, 0.5, 0.78, 0.24, WHITE)
	ring.BackgroundTransparency = 1
	round(ring, size)
	stroke(ring, color:Lerp(WHITE, 0.45), math.max(2, size / 24))
	for i = 0, 2 do
		gem(root, 0.3 + i * 0.2, if i == 1 then 0.36 else 0.4, 0.11, color, size)
	end
end

local function trim(root: Frame, size: number, color: Color3)
	local glow = piece(root, 0.5, 0.5, 0.94, 0.94, color)
	glow.BackgroundTransparency = 0.8
	round(glow, size)
	local orb = piece(root, 0.5, 0.5, 0.62, 0.62, WHITE)
	round(orb, size)
	gradient(orb, color:Lerp(WHITE, 0.55), color:Lerp(BLACK, 0.35), 45)
	stroke(orb, WHITE, math.max(2, size / 24), 0.15)
	local shine = piece(orb, 0.34, 0.3, 0.26, 0.18, WHITE, -30)
	shine.BackgroundTransparency = 0.35
	round(shine, size)
end

-- The picture for a reward: a cosmetic's own look, or a drawn icon by kind.
function ShopArt.icon(parent: Instance, kind: string, cosmeticId: string?, size: number): GuiObject
	local root = canvas(parent, size, "Icon")
	local cosmetic = cosmeticId and Cosmetics.get(cosmeticId)
	if cosmetic and cosmetic.Kind == "Trim" then
		trim(root, size, cosmetic.Color)
	elseif cosmetic then
		local draw = BACKS[cosmetic.Look or ""] or BACKS.Pack
		draw(root, size, cosmetic.Color)
	else
		local draw = DRAW[kind] or DRAW.Cosmetic
		draw(root, size)
	end
	return root
end

-- A dark tile edged and lit in a rarity colour.
function ShopArt.rarityTile(parent: Instance, rarity: string, size: number): Frame
	local color = GemConfig.TierColors[rarity] or Color3.fromRGB(200, 200, 200)
	local tile = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = WHITE }, parent)
	round(tile, math.floor(size * 0.12))
	gradient(tile, color:Lerp(P.Inset, 0.62), P.Frame)
	stroke(tile, color, 1.5, 0.15)
	local rail = new("Frame", {
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -16, 0, 2),
	}, tile)
	round(rail, 1)
	return tile
end

return ShopArt
