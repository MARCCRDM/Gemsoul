-- Rolls new gemstones and grades cuts, following GemConfig. Pure logic with
-- no Roblox services, so it can be tested outside the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

local GemGenerator = {}

type Gem = GemConfig.Gem

local function weightedIndex(rng: Random, weights: { number }): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber(0, total)
	for i, weight in weights do
		roll -= weight
		if roll <= 0 then
			return i
		end
	end
	return #weights
end

-- A 1-10 grade. With luck, sometimes roll twice and keep the better result.
local function rollGrade(rng: Random, luck: number): number
	local grade = weightedIndex(rng, GemConfig.GradeWeights)
	if luck > 0 and rng:NextNumber() < luck then
		grade = math.max(grade, weightedIndex(rng, GemConfig.GradeWeights))
	end
	return grade
end

local function rollShade(rng: Random, element: string, luck: number): string
	local shades = GemConfig.Shades[element]
	local weights = {}
	for i, shade in shades do
		local weight = GemConfig.TierWeights[shade.Tier]
		if i == 2 then
			weight *= 1 + luck
		elseif i == 3 then
			weight *= 1 + 3 * luck
		end
		weights[i] = weight
	end
	return shades[weightedIndex(rng, weights)].Tier
end

--[[
	Recovers a naturally faceted, enchant-ready gemstone.
	source: "MiningNode" | "MiningStore" | "PvEDrop" | "PvPWager"
	opts.Luck: extra luck on top of the source's own (0-1)
	opts.Id: unique id (the server passes a GUID)
]]
function GemGenerator.generate(rng: Random, source: string, opts: { Luck: number?, Id: string, Time: number }): Gem
	local luck = math.clamp((GemConfig.SourceLuck[source] or 0) + (opts.Luck or 0), 0, 1)
	local element = GemConfig.Elements[rng:NextInteger(1, #GemConfig.Elements)]
	return {
		Id = opts.Id,
		Element = element,
		Tier = rollShade(rng, element, luck),
		Clarity = rollGrade(rng, luck),
		Size = rollGrade(rng, luck),
		Cut = rollGrade(rng, luck),
		CutMethod = "Natural",
		Source = if source == "VipMiningNode" then "MiningNode" else source,
		Found = opts.Time,
	}
end

return GemGenerator
