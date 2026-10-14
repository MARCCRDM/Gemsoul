--[[
	ArenaStreak: rewards for a run of Ranked 1v1 wins in a row.

	Every milestone (10, 20 ... 100, 150, 200 wins) opens an Arena Cache: a
	spread of Legendary pieces, gems and gear, to choose from. You keep two;
	the rest go up on the Market (the "Arena Vault"), for anyone to buy.
	Higher milestones offer more to choose from, better pieces (gear rolled
	at higher quality; from 100 wins, Flawless gems: every metric maxed and
	the surge at its top rank), more coins, and a title at the big ones.

	The streak counts Ranked 1v1 wins only; a loss resets it; beating the
	same player twice in a row doesn't add to it (no trading wins with a
	friend). Each milestone pays once per season.

	  ArenaStreak.Milestones                       the table below
	  ArenaStreak.reached(before, after) -> { m }  milestones crossed
	  ArenaStreak.next(streak) -> m?               the next one up
	  ArenaStreak.counts(record, opponentId) -> bool   does this win add?
	  ArenaStreak.vaultPrice(item) -> coins        a leftover's Market price

	(Milestones past 200 come later: 250 ... 1000.)
]]
local ArenaStreak = {}

ArenaStreak.Picks = 2 -- pieces you keep from each cache

-- Wins: the streak. Choices: Legendary pieces offered (about half gems,
-- half gear). Quality: the gear's quality roll (1-4). Flawless: gems with
-- every metric at 10 and the surge at its top rank. Coins: paid at once.
-- Title: a cosmetic title (Shared.Cosmetics, Exclusive "Ranked").
ArenaStreak.Milestones = {
	{ Wins = 10, Name = "Contender", Choices = 4, Quality = 2, Coins = 2500 },
	{ Wins = 20, Name = "Challenger", Choices = 4, Quality = 2, Coins = 5000 },
	{ Wins = 30, Name = "Gladiator", Choices = 5, Quality = 3, Coins = 7500, Title = "TitleStreak30" },
	{ Wins = 40, Name = "Vanquisher", Choices = 5, Quality = 3, Coins = 10000 },
	{ Wins = 50, Name = "Warlord", Choices = 6, Quality = 3, Coins = 15000, Title = "TitleStreak50" },
	{ Wins = 60, Name = "Juggernaut", Choices = 6, Quality = 4, Coins = 20000 },
	{ Wins = 70, Name = "Ironclad", Choices = 6, Quality = 4, Coins = 25000 },
	{ Wins = 80, Name = "Dreadnought", Choices = 7, Quality = 4, Coins = 30000 },
	{ Wins = 90, Name = "Conqueror", Choices = 7, Quality = 4, Coins = 40000 },
	{
		Wins = 100,
		Name = "Centurion",
		Choices = 8,
		Quality = 4,
		Coins = 60000,
		Flawless = true,
		Title = "TitleStreak100",
	},
	{
		Wins = 150,
		Name = "Untouchable",
		Choices = 9,
		Quality = 4,
		Coins = 100000,
		Flawless = true,
		Title = "TitleStreak150",
	},
	{
		Wins = 200,
		Name = "Arena Legend",
		Choices = 10,
		Quality = 4,
		Coins = 150000,
		Flawless = true,
		Title = "TitleStreak200",
	},
}

-- What a leftover costs on the Market: gear at a flat price by quality,
-- gems at three times their worth (never under the gem floor).
ArenaStreak.VaultGear = { 12000, 15000, 18000, 22000 } -- by quality 1-4
ArenaStreak.VaultGemFloor = 12000
ArenaStreak.VaultGemMultiplier = 3
ArenaStreak.VaultName = "Arena Vault"

-- The milestones crossed going from `before` wins to `after`.
function ArenaStreak.reached(before: number, after: number)
	local crossed = {}
	for _, m in ArenaStreak.Milestones do
		if before < m.Wins and after >= m.Wins then
			table.insert(crossed, m)
		end
	end
	return crossed
end

function ArenaStreak.get(wins: any)
	for _, m in ArenaStreak.Milestones do
		if m.Wins == wins then
			return m
		end
	end
	return nil
end

-- The next milestone above `streak` (nil past the last).
function ArenaStreak.next(streak: number)
	for _, m in ArenaStreak.Milestones do
		if m.Wins > streak then
			return m
		end
	end
	return nil
end

-- Whether a win over `opponentId` adds to the streak: not when it's the
-- same player you beat last time.
function ArenaStreak.counts(record, opponentId: number?): boolean
	return opponentId == nil or record.StreakLastBeaten ~= opponentId
end

-- A leftover's Market price. `item` is a Market payload; `gemValue` the
-- gem's worth (GemConfig.value), passed in to keep this module pure.
function ArenaStreak.vaultPrice(item, gemValue: number?): number
	if item.Kind == "Gem" then
		return math.max(ArenaStreak.VaultGemFloor, math.floor((gemValue or 0) * ArenaStreak.VaultGemMultiplier))
	end
	return ArenaStreak.VaultGear[math.clamp(item.Quality or 1, 1, #ArenaStreak.VaultGear)]
end

-- How many gems and how many gear pieces a cache of `choices` holds.
function ArenaStreak.split(choices: number): (number, number)
	local gems = math.floor(choices / 2)
	return gems, choices - gems
end

return ArenaStreak
