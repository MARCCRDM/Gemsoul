--[[
	Little pieces of drawn UI art for the Shop and crate reveal:
	  ShopArt.crate(parent, size, glow)      a banded wooden crate with a
	                                          glowing gem set in the front
	  ShopArt.icon(parent, kind, cosmetic?, size)  what a reward looks like
	  ShopArt.rarityTile(parent, rarity, size)     a tile in a rarity colour
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local IronUi = require(script.Parent.IronUi)

local new = IronUi.new
local P = IronUi.Colors

local ShopArt = {}

ShopArt.BackIcons = { Pack = "🎒", Banner = "🚩", Geode = "🔮", Cape = "🧥", Wings = "🦋", Halo = "💫" }
ShopArt.KindIcons =
	{ Stones = "🪨", Materials = "⚒️", Marks = "🎖️", CutGems = "💎", Coins = "💰", Cosmetic = "✨" }

local function round(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) }, parent)
end

-- A crate drawn from frames: body, lid, iron bands, and a glowing gem.
function ShopArt.crate(parent: Instance, size: number, glow: Color3?): Frame
	local color = glow or Color3.fromRGB(90, 230, 255)
	local root = new("Frame", {
		Name = "Crate",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
	}, parent)
	-- Soft glow behind.
	local halo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(1.05, 1.05),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.8,
	}, root)
	round(halo, size)
	local body = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.86, 0.56),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, root)
	round(body, math.floor(size * 0.06))
	gradient(body, Color3.fromRGB(176, 118, 66), Color3.fromRGB(96, 58, 32))
	new("UIStroke", { Color = P.Ink, Thickness = math.max(2, size / 60) }, body)
	-- Plank lines.
	for _, y in { 0.34, 0.67 } do
		new("Frame", {
			BackgroundColor3 = Color3.fromRGB(70, 40, 22),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.new(0.92, 0, 0, math.max(1, size / 90)),
		}, body)
	end
	local lid = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.94, 0.24),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, root)
	round(lid, math.floor(size * 0.06))
	gradient(lid, Color3.fromRGB(196, 136, 78), Color3.fromRGB(120, 74, 40))
	new("UIStroke", { Color = P.Ink, Thickness = math.max(2, size / 60) }, lid)
	-- Iron bands over lid and body.
	for _, x in { 0.2, 0.8 } do
		local band = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, 0.19),
			Size = UDim2.fromScale(0.1, 0.76),
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, root)
		round(band, 3)
		gradient(band, Color3.fromRGB(200, 205, 215), Color3.fromRGB(90, 94, 104), 0)
		new("UIStroke", { Color = P.Ink, Thickness = math.max(1.5, size / 80) }, band)
	end
	-- Crystals poking out of the lid.
	for i, spec in { { 0.38, -18, 0.13 }, { 0.5, 6, 0.18 }, { 0.62, 22, 0.12 } } do
		local shard = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(spec[1], 0.22),
			Size = UDim2.fromScale(0.09, spec[3]),
			Rotation = spec[2],
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 0,
		}, root)
		round(shard, 3)
		gradient(shard, color:Lerp(Color3.new(1, 1, 1), 0.6), color)
		shard.LayoutOrder = i
	end
	-- The gem set in the front.
	local gem = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromScale(0.26, 0.26),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, root)
	round(gem, math.floor(size * 0.03))
	gradient(gem, color:Lerp(Color3.new(1, 1, 1), 0.55), color:Lerp(Color3.new(0, 0, 0), 0.2), 45)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = math.max(2, size / 50) }, gem)
	local glint = new("Frame", {
		Position = UDim2.fromScale(0.18, 0.18),
		Size = UDim2.fromScale(0.28, 0.28),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
	}, gem)
	round(glint, 3)
	return root
end

-- A rarity-coloured rounded tile.
function ShopArt.rarityTile(parent: Instance, rarity: string, size: number): Frame
	local color = GemConfig.TierColors[rarity] or Color3.fromRGB(200, 200, 200)
	local tile = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
	round(tile, math.floor(size * 0.18))
	gradient(tile, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.5))
	new("UIStroke", { Color = P.Ink, Thickness = 2.5 }, tile)
	return tile
end

-- The picture for a reward: a cosmetic's own look, or an emoji by kind.
function ShopArt.icon(parent: Instance, kind: string, cosmeticId: string?, size: number): GuiObject
	local cosmetic = cosmeticId and Cosmetics.get(cosmeticId)
	if cosmetic and cosmetic.Kind == "Trim" then
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 0.6, size * 0.6),
			BackgroundColor3 = cosmetic.Color,
		}, parent)
		round(dot, size)
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = math.max(2, size / 20) }, dot)
		new("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
		}, dot)
		return dot
	end
	local glyph = if cosmetic then ShopArt.BackIcons[cosmetic.Look or ""] or "✨" else ShopArt.KindIcons[kind] or "✨"
	return new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Text = glyph,
		TextSize = math.floor(size * 0.72),
		Font = IronUi.Chunky,
	}, parent)
end

return ShopArt
