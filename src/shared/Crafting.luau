-- Compatibility module name: recovered equipment quality and gem exchange prices.
-- There are no crafting recipes, upgrade services or salvage materials.
local Config = require(script.Parent.Config)
local GemConfig = require(script.Parent.GemConfig)
local Crafting = {}
export type Quality = { Name: string, Color: Color3 }

Crafting.Qualities = {
	{ Name = "Standard", Color = Color3.fromRGB(225, 225, 225) },
	{ Name = "Fine", Color = Color3.fromRGB(90, 220, 90) },
	{ Name = "Superior", Color = Color3.fromRGB(80, 150, 255) },
	{ Name = "Masterwork", Color = Color3.fromRGB(255, 150, 40) },
} :: { Quality }
Crafting.MaxQuality = #Crafting.Qualities

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

-- What Tamsin at the Market pays for a stone, in coins.
function Crafting.marketPrice(gem: GemConfig.Gem): number
	return math.max(1, math.floor(GemConfig.value(gem) * Config.MarketSellRate))
end

return Crafting
