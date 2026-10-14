--[[
	ArenaStreak: rewards for a run of Ranked 1v1 wins in a row.

	Every milestone (10, 20 ... 100, 150, 200 wins) opens an Arena Cache:
	  - gems, free: every one is yours (Rare, then Ultra-Rare from 50 wins,
	    Flawless from 100: every metric maxed, the surge at its top rank);
	  - six pieces of gear, Rare and Ultra-Rare, rolled to choose from: you
	    keep three. The other three go up on the Market from the Arena Vault,
	    and when one sells you get a 25% commission on its price.
	Higher milestones offer more Ultra-Rare gear (all six from 150), more
	and better gems, gear at higher quality, more coins, and a title at the
	big ones.

	The streak counts Ranked 1v1 wins only; a loss resets it; beating the
	same player twice in a row doesn't add to it (no trading wins with a
	friend). Each milestone pays once per season.

	  ArenaStreak.Milestones                       the table below
	  ArenaStreak.reached(before, after) -> { m }  milestones crossed
	  ArenaStreak.next(streak) -> m?               the next one up
	  ArenaStreak.counts(record, opponentId) -> bool   does this win add?
	  ArenaStreak.rarities(m) -> gemTiers, gearTiers   each piece's rarity
	  ArenaStreak.vaultPrice(item, worth, rarity) -> coins   a leftover's price
	  ArenaStreak.commission(price) -> coins       your cut when one sells

	(Milestones past 200 come later: 250 ... 1000.)
]]
local ArenaStreak = {}

ArenaStreak.GearOffered = 6 -- pieces of gear to choose from
ArenaStreak.Picks = 3 -- of which you keep
ArenaStreak.Commission = 0.25 -- your cut of a leftover's Market price

-- Wins: the streak. Gems: free gems (all yours), GemTier their rarity.
-- UltraRare: how many of the six pieces of gear are Ultra-Rare (the rest
-- Rare). Quality: the gear's quality roll (1-4). Flawless: gems with every
-- metric at 10 and the surge at its top rank. Coins: paid at once.
-- Title: a cosmetic title (Shared.Cosmetics, Exclusive "Ranked").
ArenaStreak.Milestones = {
	{ Wins = 10, Name = "Contender", Gems = 1, GemTier = "Rare", UltraRare = 1, Quality = 2, Coins = 2500 },
	{ Wins = 20, Name = "Challenger", Gems = 1, GemTier = "Rare", UltraRare = 1, Quality = 2, Coins = 5000 },
	{
		Wins = 30,
		Name = "Gladiator",
		Gems = 2,
		GemTier = "Rare",
		UltraRare = 2,
		Quality = 3,
		Coins = 7500,
		Title = "TitleStreak30",
	},
	{ Wins = 40, Name = "Vanquisher", Gems = 2, GemTier = "Rare", UltraRare = 2, Quality = 3, Coins = 10000 },
	{
		Wins = 50,
		Name = "Warlord",
		Gems = 2,
		GemTier = "UltraRare",
		UltraRare = 3,
		Quality = 3,
		Coins = 15000,
		Title = "TitleStreak50",
	},
	{ Wins = 60, Name = "Juggernaut", Gems = 2, GemTier = "UltraRare", UltraRare = 3, Quality = 4, Coins = 20000 },
	{ Wins = 70, Name = "Ironclad", Gems = 3, GemTier = "UltraRare", UltraRare = 4, Quality = 4, Coins = 25000 },
	{ Wins = 80, Name = "Dreadnought", Gems = 3, GemTier = "UltraRare", UltraRare = 4, Quality = 4, Coins = 30000 },
	{ Wins = 90, Name = "Conqueror", Gems = 3, GemTier = "UltraRare", UltraRare = 5, Quality = 4, Coins = 40000 },
	{
		Wins = 100,
		Name = "Centurion",
		Gems = 3,
		GemTier = "UltraRare",
		UltraRare = 5,
		Quality = 4,
		Coins = 60000,
		Flawless = true,
		Title = "TitleStreak100",
	},
	{
		Wins = 150,
		Name = "Untouchable",
		Gems = 4,
		GemTier = "UltraRare",
		UltraRare = 6,
		Quality = 4,
		Coins = 100000,
		Flawless = true,
		Title = "TitleStreak150",
	},
	{
		Wins = 200,
		Name = "Arena Legend",
		Gems = 5,
		GemTier = "UltraRare",
		UltraRare = 6,
		Quality = 4,
		Coins = 150000,
		Flawless = true,
		Title = "TitleStreak200",
	},
}

-- The two rarities a cache draws from (GemConfig tier names), and the gear
-- RarityTier each one is.
ArenaStreak.Rarities = { "Rare", "UltraRare" }
ArenaStreak.GearTier = { Rare = 3, UltraRare = 4 }

-- What a leftover costs on the Market: gear at a flat price by rarity and
-- quality, gems at three times their worth (never under their rarity's floor).
ArenaStreak.VaultGear = {
	Rare = { 4000, 5000, 6000, 7500 }, -- by quality 1-4
	UltraRare = { 8000, 10000, 12000, 15000 },
}
ArenaStreak.VaultGemFloor = { Rare = 4000, UltraRare = 8000 }
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

-- A leftover's Market price. `item` is a Market payload, `rarity` its
-- rarity ("Rare" or "UltraRare"; a gem's own tier when left out), and
-- `gemValue` a gem's worth (GemConfig.value), passed in to keep this pure.
function ArenaStreak.vaultPrice(item, gemValue: number?, rarity: string?): number
	local tier = rarity or (item.Gem and item.Gem.Tier)
	tier = if tier == "UltraRare" then "UltraRare" else "Rare"
	if item.Kind == "Gem" then
		return math.max(ArenaStreak.VaultGemFloor[tier], math.floor((gemValue or 0) * ArenaStreak.VaultGemMultiplier))
	end
	local prices = ArenaStreak.VaultGear[tier]
	return prices[math.clamp(item.Quality or 1, 1, #prices)]
end

-- Your commission when a leftover of your cache sells for `price`.
function ArenaStreak.commission(price: number): number
	return math.floor((tonumber(price) or 0) * ArenaStreak.Commission)
end

-- The rarity of each piece in a cache for milestone `m`: a list for its
-- free gems and one for its six pieces of gear (Ultra-Rare first).
function ArenaStreak.rarities(m): ({ string }, { string })
	local gems, gear = {}, {}
	for i = 1, m.Gems or 0 do
		gems[i] = m.GemTier or "Rare"
	end
	local ultra = math.clamp(m.UltraRare or 0, 0, ArenaStreak.GearOffered)
	for i = 1, ArenaStreak.GearOffered do
		gear[i] = if i <= ultra then "UltraRare" else "Rare"
	end
	return gems, gear
end

return ArenaStreak
