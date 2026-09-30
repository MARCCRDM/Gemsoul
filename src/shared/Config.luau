-- Game-wide settings shared by server and client.
local Config = {
	-- Menu-first: everything (mining, cutting, crafting, selling, the shop)
	-- is played from the menu. Combat and walking around the town are paused
	-- while this is on: no monsters, no hotbar, and the camera shows the
	-- kingdom behind the menu.
	MenuOnly = true,

	-- Free mining: each mined node uses one free mine. When the daily or
	-- weekly allowance runs out, players buy rough stones at the Mining Store.
	DailyQuota = 10,
	WeeklyQuota = 50,

	-- Economy
	StartingCoins = 300,
	RoughStonePrice = 60, -- Mining Store; a random rough stone averages ~51 coins
	MaxGems = 200, -- inventory limit
	-- Daily reward: base coins, plus more per day of streak (up to a week).
	DailyRewardBase = 75,
	DailyRewardPerStreak = 25,
	DailyStreakMax = 7,
	-- Tamsin at the Market buys stones for coins at this share of their value
	-- (Hilde pays 60% in Guild Marks at the Crafting Hall).
	MarketSellRate = 0.5,

	MineHoldSeconds = 1,

	-- Saving (needs "Enable Studio Access to API Services" to work in Studio).
	DataStoreName = "GemSoul_PlayerData_v1",
	AutosaveSeconds = 120,

	-- VIP: set this to your game pass id once you create one.
	VipGamePassId = 0,
	-- Treat everyone as VIP while testing in Studio so you can walk through the gate.
	VipInStudio = true,
}

return Config
