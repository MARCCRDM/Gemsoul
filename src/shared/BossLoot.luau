--[[
	BossLoot: what a brainrot boss (Shared.DungeonRules.Bosses) drops when it
	falls, in the Rift or a pathway dungeon. Everyone who fought it gets a
	boss cache of their own, rolled and picked like an Arena Cache
	(Systems/ArenaStreaks, Client StreakRewards):

	  - its gem, free: of the boss's element, Ultra Rare (Legendary from a
	    tier-5 boss), its surge at tier 4, rank III (Dungeons.bossGem);
	  - more free gems by its threat, of its element too;
	  - six pieces of gear to choose from, keep three: Ultra Rare by its
	    threat, the rest Rare, FocusCount of them its favourite kind (its
	    Loot). The other three go up on the Market from the Rift Vault,
	    and you get a cut of each sale (ArenaStreak.Commission).

	Its threat (1 to 3, its Threat) also makes it tougher (Health).

	  BossLoot.Threats[threat]            the table below
	  BossLoot.threat(boss) -> 1..3       a boss's (2 when it has none)
	  BossLoot.spec(boss) -> m            its cache, as an Arena Cache
	                                      milestone (ArenaStreaks.rollCache)
	  BossLoot.health(boss) -> number     its health, times
	  BossLoot.numeral(threat) -> "I"...  on its cache and the gate
]]
local BossLoot = {}

-- Gems: free gems beyond its own, GemTier their rarity. UltraRare: how many
-- of the six pieces of gear are Ultra Rare (the rest Rare). Quality: the
-- gear's quality roll (1-4). Health: the boss's health, times.
BossLoot.Threats = {
	{ Gems = 0, GemTier = "Rare", UltraRare = 1, Quality = 2, Health = 0.85 },
	{ Gems = 1, GemTier = "Rare", UltraRare = 2, Quality = 3, Health = 1 },
	{ Gems = 1, GemTier = "UltraRare", UltraRare = 3, Quality = 3, Health = 1.2 },
}
BossLoot.FocusCount = 2 -- pieces of its favourite kind among the six
BossLoot.VaultName = "Rift Vault" -- where its leftovers go up on the Market

local NUMERALS = { "I", "II", "III" }

function BossLoot.threat(boss): number
	local threat = type(boss) == "table" and tonumber(boss.Threat) or 2
	return math.clamp(math.floor(threat or 2), 1, #BossLoot.Threats)
end

function BossLoot.numeral(threat: number): string
	return NUMERALS[threat] or tostring(threat)
end

-- Its cache, in an Arena Cache milestone's terms (Gems, GemTier, UltraRare,
-- Quality), plus its element for the gems and its favourite kind of gear.
function BossLoot.spec(boss)
	local rules = BossLoot.Threats[BossLoot.threat(boss)]
	return {
		Wins = 0,
		Name = boss.Name,
		Gems = rules.Gems,
		GemTier = rules.GemTier,
		UltraRare = rules.UltraRare,
		Quality = rules.Quality,
		Element = boss.Element,
		Focus = boss.Loot,
		FocusCount = BossLoot.FocusCount,
	}
end

function BossLoot.health(boss): number
	return BossLoot.Threats[BossLoot.threat(boss)].Health
end

return BossLoot
