-- Migration and reward compatibility for the loot-and-trade expedition economy.
local Economy = {}
local rates = { Iron = 12, Timber = 8, Leather = 10, Cloth = 10, Mithril = 60, Shards = 20 }

--[[
	Gem potency is an economy number only; combat reads Size, Clarity and Cut
	directly (GemConfig.stats). Cut weighs most because precision is the
	rarest endgame stat.
	  Value = Base Tier Value x (Size x 10 + Clarity x 5 + Cut x 15) x scale
	The scale keeps the average mined gem's price where the economy expects it.
]]
Economy.GemValueScale = 0.045
function Economy.gemPotency(gem)
	return gem.Size * 10 + gem.Clarity * 5 + (gem.Cut or 0) * 15
end
function Economy.gemValue(gem, tierValue)
	return math.max(1, math.floor(tierValue * Economy.gemPotency(gem) * Economy.GemValueScale + 0.5))
end
function Economy.legacyCredits(marks, materials)
	local coins = math.max(0, marks or 0)
	for id, count in materials or {} do
		coins += math.max(0, count) * (rates[id] or 1)
	end
	return math.floor(coins)
end
function Economy.migrate(profile, rng)
	local gems, seen = {}, {}
	local function collect(gem)
		if not gem then
			return
		end
		table.insert(gems, gem)
		if gem.Cut then
			seen[gem.Id] = gem.Cut
		end
	end
	for _, gem in profile.Gems or {} do
		collect(gem)
	end
	local c = profile.Character
	for _, slot in { "Weapon", "Armor", "Helmet", "Gloves", "Boots", "Shield" } do
		collect(c[slot .. "Gem"])
		for _, gem in c.ItemGems and c.ItemGems[slot] or {} do
			collect(gem)
		end
	end
	for _, gem in gems do
		if not gem.Cut then
			gem.Cut = seen[gem.Id] or rng:NextInteger(1, 10)
			gem.CutMethod = "Natural"
			seen[gem.Id] = gem.Cut
		end
	end
	if profile.ExpeditionEconomyVersion ~= 1 then
		profile.Coins += Economy.legacyCredits(profile.Marks, profile.Materials)
		profile.Marks = 0
		profile.Materials = {}
		profile.ExpeditionEconomyVersion = 1
	end
end
return Economy
