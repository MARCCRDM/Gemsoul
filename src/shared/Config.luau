-- Game-wide settings shared by server and client.
local Config = {
	-- Menu-first: everything (mining, trading, enchanting, selling and the shop)
	-- is played from the menu. Combat and walking around the town are paused
	-- while this is on: no monsters, no hotbar, and the camera shows the
	-- kingdom behind the menu.
	MenuOnly = true,
	-- Arena combat is playable from the dashboard without enabling the old town loop.
	CombatEnabled = true,
	-- Only this class is playable for now; everyone is set to it (with its
	-- random equipment set). nil opens all classes again.
	OnlyClass = "Warrior",

	-- Free mining: each mined node uses one free mine. When the daily or
	-- weekly allowance runs out, players fund more mine walls with coins.
	DailyQuota = 10,
	WeeklyQuota = 50,

	-- Economy
	StartingCoins = 300,
	MaxGems = 200, -- inventory limit
	-- Daily reward: base coins, plus more per day of streak (up to a week).
	DailyRewardBase = 75,
	DailyRewardPerStreak = 25,
	DailyStreakMax = 7,
	-- Tamsin at the Market buys stones for coins at this share of their value
	MarketSellRate = 0.5,

	MineHoldSeconds = 1,

	-- Saving (needs "Enable Studio Access to API Services" to work in Studio).
	DataStoreName = "GemSoul_PlayerData_v1",
	AutosaveSeconds = 120,

	-- Playtesting with friends on a published server.
	Playtest = {
		-- Shown on the dashboard and stamped on every report, so feedback
		-- names the build it came from. Change it whenever you publish.
		Build = "Playtest 1 · 2026-10-03",
		-- UserIds who can read feedback and error reports in game (Social >
		-- Feedback > Reports). In Studio everyone can.
		Owners = { 11738957136, 11758049015 }, -- Devvolver, VolverDev
		-- UserIds who get the test-admin tools (e.g. regenerating gear).
		Testers = { 11758049015 }, -- VolverDev
		-- Everyone gets the test-admin tools while testing. Turn off for launch.
		OpenAdmin = true,
	},

	-- VIP: set this to your game pass id once you create one.
	VipGamePassId = 0,
	-- Treat everyone as VIP while testing in Studio so you can walk through the gate.
	VipInStudio = true,
}

return Config
