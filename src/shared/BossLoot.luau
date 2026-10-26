--[[
	BossLoot: what a brainrot boss (Shared.DungeonRules.Bosses) drops when it
	falls, in the Rift or a pathway dungeon. Everyone who fought it gets a
	boss cache of their own, a reward like every other (Shared.RewardRoll,
	Systems/ArenaStreaks, Client StreakRewards): two pieces of gear rolled,
	keep one, FocusCount of them its favourite kind (its Loot). Their rarity
	goes by how much you've played 1v1, at least its threat's Floor. The
	other goes up on the Market from the Rift Vault, and you get a cut of
	its sale (ArenaStreak.Commission).

	Its threat (1 to 3, its Threat) also makes it tougher (Health).

	  BossLoot.Threats[threat]            the table below
	  BossLoot.threat(boss) -> 1..3       a boss's (2 when it has none)
	  BossLoot.spec(boss) -> m            its cache, as an Arena Cache
	                                      milestone (ArenaStreaks.rollCache)
	  BossLoot.health(boss) -> number     its health, times
	  BossLoot.numeral(threat) -> "I"...  on its cache and the gate
]]
local BossLoot = {}

-- Floor: the least its cache rolls (RewardRoll). Quality: the gear's
-- quality roll at least (1-4). Health: the boss's health, times.
BossLoot.Threats = {
	{ Floor = "Uncommon", Quality = 2, Health = 0.85 },
	{ Floor = "Rare", Quality = 3, Health = 1 },
	{ Floor = "UltraRare", Quality = 3, Health = 1.2 },
}
BossLoot.FocusCount = 1 -- pieces of its favourite kind among the two
BossLoot.VaultName = "Rift Vault" -- where its leftovers go up on the Market

local NUMERALS = { "I", "II", "III" }

function BossLoot.threat(boss): number
	local threat = type(boss) == "table" and tonumber(boss.Threat) or 2
	return math.clamp(math.floor(threat or 2), 1, #BossLoot.Threats)
end

function BossLoot.numeral(threat: number): string
	return NUMERALS[threat] or tostring(threat)
end

-- Its cache, in an Arena Cache milestone's terms (Floor, Quality), plus
-- its element and its favourite kind of gear.
function BossLoot.spec(boss)
	local rules = BossLoot.Threats[BossLoot.threat(boss)]
	return {
		Wins = 0,
		Name = boss.Name,
		Floor = rules.Floor,
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
