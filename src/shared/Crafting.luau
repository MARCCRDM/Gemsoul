--[[
	The Crafting Hall: materials, gear quality and recipes, and what Hilde
	pays for stones.

	Every class weapon and armor can be crafted, then upgraded through four
	qualities (Diablo item colours):
	  1 Standard   white    what the intro gives you
	  2 Fine       green
	  3 Superior   blue     needs Mithril
	  4 Masterwork orange   needs Mithril and Gem Shards
	Stones are sold to Hilde the quartermaster for Guild Marks, the Crafting
	Hall's own currency. Marks buy materials and pay Borin's forge fees; Gem
	Shards come only from salvaging stones you don't want.
]]
local Config = require(script.Parent.Config)
local GemConfig = require(script.Parent.GemConfig)

local Crafting = {}

export type Material = {
	Id: string,
	Name: string,
	Description: string,
	Price: number?, -- in Guild Marks; nil: can't be bought
	Color: Color3,
}

Crafting.MaterialOrder = { "Iron", "Timber", "Leather", "Cloth", "Mithril", "Shards" }

Crafting.Materials = {
	Iron = {
		Id = "Iron",
		Name = "Iron Ingot",
		Description = "Blades, axe heads and plate.",
		Price = 12,
		Color = Color3.fromRGB(150, 155, 165),
	},
	Timber = {
		Id = "Timber",
		Name = "Seasoned Timber",
		Description = "Hafts, staves and bows.",
		Price = 8,
		Color = Color3.fromRGB(150, 105, 60),
	},
	Leather = {
		Id = "Leather",
		Name = "Tanned Leather",
		Description = "Grips, straps and leather armor.",
		Price = 10,
		Color = Color3.fromRGB(120, 72, 40),
	},
	Cloth = {
		Id = "Cloth",
		Name = "Spellweave Cloth",
		Description = "Robes, wraps and hoods.",
		Price = 10,
		Color = Color3.fromRGB(120, 90, 190),
	},
	Mithril = {
		Id = "Mithril",
		Name = "Mithril Ingot",
		Description = "Light, bright metal for Superior and Masterwork gear.",
		Price = 60,
		Color = Color3.fromRGB(170, 215, 240),
	},
	Shards = {
		Id = "Shards",
		Name = "Gem Shards",
		Description = "Salvaged from gems. Needed for Masterwork gear.",
		Price = nil,
		Color = Color3.fromRGB(0, 240, 255),
	},
} :: { [string]: Material }

export type Quality = { Name: string, Color: Color3 }

Crafting.Qualities = {
	{ Name = "Standard", Color = Color3.fromRGB(225, 225, 225) },
	{ Name = "Fine", Color = Color3.fromRGB(90, 220, 90) },
	{ Name = "Superior", Color = Color3.fromRGB(80, 150, 255) },
	{ Name = "Masterwork", Color = Color3.fromRGB(255, 150, 40) },
} :: { Quality }
Crafting.MaxQuality = #Crafting.Qualities

-- Which materials each class works with: { main, second }.
Crafting.Families = {
	Warrior = { Weapons = { "Iron", "Timber" }, Armors = { "Iron", "Leather" } },
	Tank = { Weapons = { "Iron", "Timber" }, Armors = { "Iron", "Leather" } },
	Wizard = { Weapons = { "Timber", "Cloth" }, Armors = { "Cloth", "Leather" } },
	Archer = { Weapons = { "Timber", "Leather" }, Armors = { "Leather", "Cloth" } },
}

-- Cost to reach each quality: quality 1 is crafting a new piece.
local STEPS = {
	{ Main = 4, Second = 2, Mithril = 0, Shards = 0, Marks = 40 },
	{ Main = 8, Second = 4, Mithril = 0, Shards = 0, Marks = 120 },
	{ Main = 12, Second = 6, Mithril = 3, Shards = 0, Marks = 350 },
	{ Main = 16, Second = 8, Mithril = 6, Shards = 25, Marks = 900 },
}

export type Recipe = { Materials: { [string]: number }, Marks: number }

-- What it costs a class to make `kind` ("Weapons" or "Armors") at `quality`.
function Crafting.recipe(classId: string, kind: string, quality: number): Recipe?
	local family = Crafting.Families[classId]
	local step = STEPS[quality]
	if not family or not family[kind] or not step then
		return nil
	end
	local materials = {}
	materials[family[kind][1]] = step.Main
	materials[family[kind][2]] = step.Second
	if step.Mithril > 0 then
		materials.Mithril = step.Mithril
	end
	if step.Shards > 0 then
		materials.Shards = step.Shards
	end
	return { Materials = materials, Marks = step.Marks }
end

-- Rating bonus from quality: weapons hit harder, armor protects more.
function Crafting.qualityBonus(kind: string, quality: number?): { [string]: number }
	local steps = math.max(0, (quality or 1) - 1)
	if steps == 0 then
		return {}
	end
	if kind == "Weapons" then
		return { Power = steps * 10 }
	end
	return { Defense = steps * 8, Health = steps * 6 }
end

-- Quality-coloured name, e.g. "Fine Longsword".
function Crafting.gearName(baseName: string, quality: number?): string
	local q = quality or 1
	return if q > 1 then Crafting.Qualities[q].Name .. " " .. baseName else baseName
end

-- Hilde pays 60% of a gem's coin value in Guild Marks; salvaging gives
-- shards instead.
function Crafting.sellPrice(gem: GemConfig.Gem): number
	return math.max(1, math.floor(GemConfig.value(gem) * 0.6))
end

-- What Tamsin at the Market pays for a stone, in coins.
function Crafting.marketPrice(gem: GemConfig.Gem): number
	return math.max(1, math.floor(GemConfig.value(gem) * Config.MarketSellRate))
end

function Crafting.salvageShards(gem: GemConfig.Gem): number
	return math.max(1, math.floor(GemConfig.value(gem) / 12))
end

return Crafting
