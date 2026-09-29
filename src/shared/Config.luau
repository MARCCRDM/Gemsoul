-- Game-wide settings shared by server and client.
local Config = {
	-- Free mining: each mined node uses one free mine. When the daily or
	-- weekly allowance runs out, players buy rough stones at the Mining Store.
	DailyQuota = 10,
	WeeklyQuota = 50,

	-- Economy
	StartingCoins = 300,
	RoughStonePrice = 60, -- Mining Store; a random rough stone averages ~51 coins
	MaxGems = 200, -- inventory limit

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
