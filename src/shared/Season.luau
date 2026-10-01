--[[
	The Season Path: earn XP by playing, level up, and claim a reward at
	every level (a free track, like a battle pass). 30 levels.

	XP comes from everything you do; a 2x XP boost (from bundles) doubles it.
]]
local Season = {}

Season.Name = "Season 1: Lunar Frontier"
Season.MaxLevel = 30

-- XP for each activity.
Season.XP = {
	Mine = 15,
	Sell = 5,
	Enchant = 20,
	SlayCrawler = 12,
	SlayBrute = 35,
	Daily = 50,
}

-- XP needed to go from `level` to the next.
function Season.xpToNext(level: number): number
	return 100 + 25 * (level - 1)
end

-- The reward for reaching each level (see Store.Reward).
local SPECIAL = {
	[5] = { Cosmetics = { "TrimEmber" } },
	[10] = { Cosmetics = { "BackGeode" } },
	[15] = { Cosmetics = { "TrimRoseGold" }, Crates = { MasterworkCrate = 1 } },
	[20] = { Cosmetics = { "BackWings" } },
	[25] = { Cosmetics = { "TrimPrismatic" } },
	[30] = { Cosmetics = { "BackHalo" }, Crates = { MasterworkCrate = 2 } },
}

function Season.reward(level: number): { [string]: any }
	if SPECIAL[level] then
		return SPECIAL[level]
	end
	-- A steady rhythm between the special levels.
	local step = level % 5
	if step == 1 then
		return { Coins = 100 + level * 10 }
	elseif step == 2 then
		return { Coins = 80 + level * 8 }
	elseif step == 3 then
		return { Crates = { GeodeCrate = 1 } }
	end
	return { CutGems = 1 }
end

-- Level and progress for a total XP.
function Season.levelFor(totalXp: number): (number, number, number)
	local level, remaining = 1, totalXp
	while level < Season.MaxLevel and remaining >= Season.xpToNext(level) do
		remaining -= Season.xpToNext(level)
		level += 1
	end
	return level, remaining, Season.xpToNext(level)
end

return Season
