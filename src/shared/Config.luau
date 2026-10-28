-- Game-wide settings shared by server and client.

-- Where the game is in its life. This one switch sets every launch-sensitive
-- setting together (STAGES, at the bottom):
--   "Playtest"  friends-only test servers: every join starts brand new and
--               nothing is saved, everyone gets the DEV tools, cosmetics cost
--               25 test coins.
--   "Beta"      the public beta: saves load and save, only Owners and Testers
--               get the DEV tools, cosmetics are had the normal way.
--   "Live"      launch: the same as Beta.
local STAGE = "Live"

local Config = {
	Stage = STAGE,
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
	-- Whole activities can be switched off (e.g. a combat-only playtest): the
	-- server refuses them and the menus hide them or show them as closed.
	Features = {
		Mining = true,
		Market = true,
		-- Squad dungeons and party raids (the Dungeon card, Social's dungeon
		-- buttons, DungeonFind, PartyDungeon and PartyRaid). Off for the beta
		-- until their whole entry-to-reward flow passes testing; Owners can
		-- still run them from the DEV panel's dungeon tests.
		Dungeons = false,
		-- The garage's drivable mechs (the Shelter; the Pilot prompt).
		Mechs = true,
		-- Three miners per account (Shared.MinerRoster): switch between them in
		-- the Inventory, counter-pick another between 1v1 rounds, and send the
		-- next one in when one falls in a dungeon. Off for the beta: everyone
		-- plays one miner, so there's one character to learn and to manage.
		-- Saves that already hold three keep them for when it's back on.
		MinerRoster = false,
		-- Mini kaiju in the Outpost (docs/kaiju.md): a kaiju of your own
		-- beside you, wild ones to fight or tame, moon bugs, hunting.
		Kaiju = true,
		-- 1V1 + KAIJU (Shared.KaijuBattle): duel each other on a Kaiju Arena
		-- court while your kaiju fight. Off: the pads offer the kaiju battle
		-- alone, and the Hall of Fame has no column for it.
		KaijuDuel = false,
		-- The MMO chat box (ChatFrame: tabs, channels, slash commands). Off
		-- for now: chat is the windowless feed at the bottom left (ChatFeed),
		-- and Roblox's own chat on phones and in fights.
		ChatBox = false,
	},

	-- Free mining: each mined node uses one free mine. When the daily or
	-- weekly allowance runs out, players fund more mine walls with coins.
	DailyQuota = 10,
	WeeklyQuota = 50,

	-- Economy
	-- TESTING: every weapon skin and suit can be bought for this many coins
	-- (Cosmetics.coinPrice), on top of how it's normally had. nil: they're
	-- Robux, loot or earned only. Set by the stage (STAGES).
	TestCosmeticPrice = nil,
	StartingCoins = 300,
	MaxGems = 300, -- inventory limit (room for a long session's Commons)
	MaxGear = 80, -- pieces of gear a player can hold (worn included)
	-- Daily reward: base coins, plus more per day of streak (up to a week):
	-- 750 on day one up to 2,250 on day seven (10x the beta's, 2026-10-28).
	DailyRewardBase = 750,
	DailyRewardPerStreak = 250,
	DailyStreakMax = 7,
	-- The shop buys gems at this share of their value: a quick sale, but
	-- trading with other players pays better.
	MarketSellRate = 0.25,

	MineHoldSeconds = 1,

	-- Saving (needs "Enable Studio Access to API Services" to work in Studio).
	-- Full-player reset, 2026-10-09. Keep this name stable after publishing:
	-- every account starts fresh once, then saves normally in this generation.
	-- The previous v1 store remains an inactive recovery backup. Beta progress
	-- carries into launch while this name stays; a new name wipes everyone.
	DataStoreName = "GemSoul_PlayerData_v2",
	-- The Market board and mailboxes. Raise it (and publish) to start the
	-- Market empty: every listed or offered item goes back to its owner the
	-- next time they join, and old mailbox notes are left behind.
	MarketVersion = 2,
	-- The board alone (its listings), mailboxes kept: raise it (and publish)
	-- to clear what's up for sale. Every listed or offered item goes back to
	-- its owner the next time they join, and anything already sold still
	-- pays its seller (their mailbox says so). 3: cleared for launch,
	-- 2026-10-28. (Raising MarketVersion clears the mailboxes too: a seller
	-- paid while away would get the item back instead, a copy.)
	MarketBoardVersion = 3,
	AutosaveSeconds = 120,

	-- Testing on a published server (the stage sets OpenAdmin and FreshStart).
	Playtest = {
		-- Shown on the dashboard and stamped on every report, so feedback
		-- names the build it came from. Change it whenever you publish.
		Build = "1.0 · 2026-10-28",
		-- UserIds who can read feedback and error reports in game (Social >
		-- Feedback > Reports). In Studio everyone can.
		Owners = { 11738957136, 11758049015 }, -- Devvolver, VolverDev
		-- UserIds who get the test-admin tools (e.g. regenerating gear).
		Testers = { 11758049015 }, -- VolverDev
		-- On: everyone gets the test-admin tools, not just Owners and Testers.
		OpenAdmin = false,
		-- On: every join starts as a brand-new player (zero coins, the fast
		-- start: style, element, first fight) and nothing is loaded or saved,
		-- so the first-time flow can be played again and again. Off (Beta and
		-- Live): saves load and save like the live game, and the fast start
		-- runs once per account. Owners and Testers can replay the fast start
		-- from the DEV panel either way.
		FreshStart = false,
	},

	-- VIP: set this to your game pass id once you create one.
	VipGamePassId = 0,
	-- Your Roblox group's id: joining it earns the Starforged weapon skin
	-- (Shared.FreeRewards). 0 = off (the Free tab says it's coming soon).
	GroupId = 0,
	-- Treat everyone as VIP while testing in Studio so you can walk through the gate.
	VipInStudio = true,
}

-- What each stage sets. Anything a stage leaves out keeps its value above.
local STAGES = {
	Playtest = { FreshStart = true, OpenAdmin = true, TestCosmeticPrice = 25 },
	Beta = { FreshStart = false, OpenAdmin = false, TestCosmeticPrice = false },
	Live = { FreshStart = false, OpenAdmin = false, TestCosmeticPrice = false },
}
local preset = STAGES[STAGE]
assert(preset, "Config: unknown stage " .. tostring(STAGE))
Config.Playtest.FreshStart = preset.FreshStart
Config.Playtest.OpenAdmin = preset.OpenAdmin
-- false (no test price) is stored as nil, the way the price checks expect.
Config.TestCosmeticPrice = preset.TestCosmeticPrice or nil

return Config
