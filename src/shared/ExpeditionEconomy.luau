-- Migration and reward compatibility for the loot-and-trade expedition economy.
local Economy = {}
local rates = { Iron = 12, Timber = 8, Leather = 10, Cloth = 10, Mithril = 60, Shards = 20 }
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
