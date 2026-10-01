-- Cosmetic variants are stable for an account and suit, including after reconnects.
-- Rarity affects appearance; suit bonuses come from the chosen equipment type.
local SuitTraits = {}
local rarities = { "Common", "Uncommon", "Rare", "UltraRare", "Legendary" }
local weights = { 40, 25, 20, 10, 5 }
local helmets = { "Worklight", "Survey Array", "Twin Sensors", "Recon Crest", "Command Crown" }
local visors = {
	Color3.fromRGB(55, 194, 230),
	Color3.fromRGB(242, 174, 68),
	Color3.fromRGB(126, 136, 245),
	Color3.fromRGB(226, 91, 198),
	Color3.fromRGB(98, 230, 183),
}
local finishes = {
	Color3.fromRGB(218, 146, 59),
	Color3.fromRGB(204, 218, 230),
	Color3.fromRGB(64, 142, 161),
	Color3.fromRGB(110, 89, 155),
	Color3.fromRGB(223, 183, 93),
}
function SuitTraits.forSuit(userId: number, suitId: string)
	local seed = math.abs(userId) % 2147483647
	for i = 1, #suitId do
		seed = (seed * 31 + string.byte(suitId, i)) % 2147483647
	end
	local rng = Random.new(seed)
	local function roll(): number
		local value = rng:NextInteger(1, 100)
		for i, weight in weights do
			value -= weight
			if value <= 0 then
				return i
			end
		end
		return 1
	end
	local helmet, visor, finish = roll(), roll(), roll()
	return {
		Helmet = helmet,
		HelmetName = helmets[helmet],
		HelmetRarity = rarities[helmet],
		VisorColor = visors[visor],
		VisorRarity = rarities[visor],
		FinishColor = finishes[finish],
		FinishRarity = rarities[finish],
	}
end
return SuitTraits
