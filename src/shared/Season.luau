--[[
	The Season Path: earn XP by playing, level up, and claim a reward at
	every level (a free track, like a battle pass). 30 levels. The premium
	track (bought once, for Robux) adds its own rewards at some levels,
	including cosmetics only found there.

	XP comes from everything you do; a 2x XP boost (from bundles) doubles it.
]]
local Season = {}

Season.Name = "Season 1: Lunar Frontier"
Season.MaxLevel = 30

-- XP for each activity. A rock's is its most, when you haven't mined in a
-- while: less the more you mine (Shared.Levelling.Mine).
Season.XP = {
	Mine = 10,
	Sell = 5,
	Enchant = 20,
	SlayCrawler = 12,
	SlayBrute = 35,
	Daily = 50,
	DuelWin = 40,
	DuelPlay = 15,
}

-- XP needed to go from `level` to the next.
function Season.xpToNext(level: number): number
	return 100 + 25 * (level - 1)
end

-- The reward for reaching each level (see Store.Reward).
local SPECIAL = {
	[5] = { Cosmetics = { "TrimEmber" } },
	[10] = { Cosmetics = { "BackGeode" } },
	[15] = { Cosmetics = { "TrimRoseGold", "SkinCrater" }, Coins = 800 },
	[20] = { Cosmetics = { "BackWings" } },
	[25] = { Cosmetics = { "TrimPrismatic", "SuitMoonDust" } },
	[30] = { Cosmetics = { "BackHalo" }, Coins = 1600 },
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
		return { Coins = 250 }
	end
	return { CutGems = 1 }
end

-- The premium track (Store.RobuxProducts.SeasonPremium): a second reward
-- at these levels, on top of the free one, for everyone who unlocks it.
-- Its cosmetics are only ever here.
Season.Premium = {
	[1] = { Coins = 750 },
	[5] = { Cosmetics = { "BackCape" }, XPBoostMinutes = 60 },
	[10] = { Cosmetics = { "SkinLunar" } },
	[15] = { Coins = 2600 },
	[20] = { Cosmetics = { "TitleLunar" } },
	[25] = { Cosmetics = { "TrimAmethyst" }, Coins = 800 },
	[30] = { Cosmetics = { "SuitLunar" } },
}

function Season.premiumReward(level: number): { [string]: any }?
	return Season.Premium[level]
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
