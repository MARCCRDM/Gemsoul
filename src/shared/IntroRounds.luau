--[[
	Intro rounds: a new miner's first six wins, one piece of gear each.

	After the first fight they can stay in the Arena for a ladder of rounds
	against a rival who gets better every round (and looks it: rarer suits,
	skins and visors as they climb). Each win rolls a piece for the next slot
	in Order, Uncommon at least, with a chance of Rare (and a Rare for sure by
	the last round if none has come yet), put on at once. Six wins: the whole
	set. Optional all the way: they can leave between rounds and come back
	(PLAY), and a win anywhere counts (a queued Casual or Ranked 1v1 too),
	in place of that win's usual reward. A loss eases the next try of that
	round, so nobody gets stuck. The first fight is round 1.

	Only for accounts the onboarding funnel counts (profile.Funnel: new
	players), until the set's done.

	Pure, for the server (Server.IntroRoundsServer, Server.Duelist), the
	client (Client.IntroRoundsUI) and tests.

	  IntroRounds.Count, Order, Rivals, RareChance, SetCoins, GemAfter, SetGem
	  IntroRounds.setGemTier(r) -> "Rare" | "UltraRare"   the set bonus's (r: 0..1)
	  IntroRounds.state(profile) -> state?      (made for eligible accounts)
	  IntroRounds.eligible(profile) -> bool     rounds left to win
	  IntroRounds.round(state) -> number        the round being fought (1..Count)
	  IntroRounds.slot(round) -> string         the slot that round pays
	  IntroRounds.rarity(state, r) -> "Uncommon" | "Rare"   (r: 0..1)
	  IntroRounds.won(state, rarity) -> round   records a win: the round it paid
	  IntroRounds.lost(state)                   records a loss of this round
	  IntroRounds.difficulty(round, losses) -> { Damage, Rate, Lunge }
	  IntroRounds.looks(round) -> cosmetics?    the rival's outfit
	  IntroRounds.view(state) -> { Won, Round, Count, Losses, Slots, Done }

	The dungeon path (Config.Features.IntroDungeon, and the Owners always):
	only the first Duels pieces are 1v1 rounds. Then the kaiju roll and the
	intro dungeon (Shared.DungeonRules.First): clearing its first room pays
	the next piece (RoomPieces), beating its boss, Tung Tung Tung Sahur, the rest.
	  IntroRounds.stage(state, dungeon) -> "Duel" | "Dungeon" | "Done"
	  IntroRounds.dungeonPieces(state, where) -> number   pieces a dungeon
	                              moment pays ("Room" or "Boss")
]]
local IntroRounds = {}

IntroRounds.Count = 6
-- What each round pays, in order: what you'll feel in the very next fight first.
IntroRounds.Order = { "Weapon", "Shield", "Armor", "Gloves", "Boots", "Helmet" }
IntroRounds.SlotNames = { Weapon = "SWORD", Shield = "SHIELD", Armor = "CHEST", Gloves = "GLOVES", Boots = "BOOTS", Helmet = "HELMET" }
IntroRounds.RareChance = 0.15
IntroRounds.SetCoins = 500 -- the whole set won
IntroRounds.Duels = 2 -- on the dungeon path, the 1v1 rounds before the dungeon
IntroRounds.RoomPieces = 1 -- the dungeon's first room cleared: this many pieces (the boss: the rest)
IntroRounds.GemAfter = 3 -- this round's win also gives a gem (socket it: Shared.FirstSteps)
-- The first dungeon (HUNT BOUNTY) on offer once this many rounds are won:
-- all six, so the set comes first; the set's card then has one way on,
-- the bounty (and the Outpost, its pod's drop, once it's cleared). Server
-- IntroRoundsServer.huntNext / choose.
IntroRounds.ChoiceAfter = 6
-- The first dungeon (HUNT BOUNTY) cleared: its coins (Server.RiftServer's
-- victory, in place of a run's usual), and a new kaiju (the boss's roll:
-- Client IntroFinale opens the lobby's intro with it).
IntroRounds.FirstDungeonCoins = 1000
-- The set bonus: all six won, a mystery gem (any element), Rare or
-- Ultra-Rare by these odds; once an account. The round cards show it
-- coming (Client IntroRoundsUI's SET BONUS strip), the last one reveals it.
IntroRounds.SetGem = {
	{ Tier = "Rare", Chance = 0.75 },
	{ Tier = "UltraRare", Chance = 0.25 },
}
-- The set bonus's rarity for a roll `r` (0..1).
function IntroRounds.setGemTier(r: number): string
	local at = 0
	for _, entry in IntroRounds.SetGem do
		at += entry.Chance
		if r < at then
			return entry.Tier
		end
	end
	return IntroRounds.SetGem[#IntroRounds.SetGem].Tier
end

-- The ladder: who you fight each round, how hard they hit (of a full Arena
-- rival's damage), how fast they swing (their swing gap, times the rules'),
-- how much health they have (of their own kit's), and what they wear
-- (Shared.Cosmetics: none exclusive). Each round's harder than the last, and
-- by more than the piece you won makes you stronger: the last two outhit a
-- full Arena rival. Round 1 is the first fight's softened sparring partner
-- (Server.Duelist's own).
IntroRounds.Rivals = {
	{ Name = "Pell", Title = "THE ROOKIE", Damage = 0.5, Rate = 1.35, Health = 0.9 },
	{
		Name = "Vera Coppercoil", Title = "THE TINKERER", Damage = 0.68, Rate = 1.2, Health = 1.0,
		Looks = { Suit = "SuitCopper", Skin = "SkinCopper", Visor = "VisorLime", Trim = "TrimEmber" },
	},
	{
		Name = "Sable", Title = "THE SHADOW", Damage = 0.82, Rate = 1.1, Health = 1.12,
		Looks = { Suit = "SuitStealth", Skin = "SkinToxic", Visor = "VisorTwilight", Trim = "TrimVenom", Back = "BackBanner" },
	},
	{
		Name = "Korr", Title = "THE STORMCALLER", Damage = 0.96, Rate = 1.02, Health = 1.25, Lunge = true,
		Looks = { Suit = "SuitStorm", Skin = "SkinPlasma", Visor = "VisorIon", Trim = "TrimStorm", Helmet = "HelmetArenaPlume", Back = "BackCape" },
	},
	{
		Name = "Magmar", Title = "THE FORGEBORN", Damage = 1.1, Rate = 0.95, Health = 1.4, Lunge = true,
		Looks = { Suit = "SuitObsidian", Skin = "SkinMolten", Visor = "VisorThermal", Trim = "TrimEmber", Helmet = "HelmetShogun", Back = "BackWings" },
	},
	{
		Name = "Nova", Title = "THE CHAMPION", Damage = 1.25, Rate = 0.88, Health = 1.6, Lunge = true,
		Looks = { Suit = "SuitNebula", Skin = "SkinSolar", Visor = "VisorSupernova", Trim = "TrimPrismatic", Helmet = "HelmetWyrmking", Back = "BackHalo" },
	},
}
-- Each loss of a round eases its next try: this much less damage, this
-- much slower swings and this much less health, a loss at a time, never
-- under Floor (damage) or HealthFloor.
IntroRounds.Ease = { Damage = 0.85, Rate = 1.1, Health = 0.9, Floor = 0.4, HealthFloor = 0.6 }

function IntroRounds.state(profile)
	if type(profile) ~= "table" then
		return nil
	end
	local state = profile.IntroRounds
	if type(state) ~= "table" then
		if type(profile.Funnel) ~= "table" then
			return nil
		end
		state = { Won = 0, Losses = 0, Rare = false, Pieces = {} }
		profile.IntroRounds = state
	end
	state.Won = math.clamp(tonumber(state.Won) or 0, 0, IntroRounds.Count)
	state.Losses = math.max(0, tonumber(state.Losses) or 0)
	state.Pieces = if type(state.Pieces) == "table" then state.Pieces else {}
	return state
end

function IntroRounds.eligible(profile): boolean
	local state = IntroRounds.state(profile)
	return state ~= nil and state.Won < IntroRounds.Count
end

function IntroRounds.round(state): number
	return math.min(IntroRounds.Count, (state and state.Won or 0) + 1)
end

function IntroRounds.slot(round: number): string
	return IntroRounds.Order[math.clamp(round, 1, IntroRounds.Count)]
end

-- The piece's rarity: Uncommon, or Rare on a lucky roll; the last round's is
-- Rare if none has been yet.
function IntroRounds.rarity(state, r: number): string
	if IntroRounds.round(state) >= IntroRounds.Count and not state.Rare then
		return "Rare"
	end
	return if r < IntroRounds.RareChance then "Rare" else "Uncommon"
end

function IntroRounds.won(state, rarity: string?): number
	local round = IntroRounds.round(state)
	if state.Won >= IntroRounds.Count then
		return 0
	end
	state.Won += 1
	state.Losses = 0
	if rarity == "Rare" then
		state.Rare = true
	end
	return round
end

function IntroRounds.lost(state)
	if state.Won < IntroRounds.Count then
		state.Losses += 1
	end
end

function IntroRounds.difficulty(round: number, losses: number?)
	local rival = IntroRounds.Rivals[math.clamp(round, 1, IntroRounds.Count)]
	local n = math.max(0, losses or 0)
	return {
		Damage = math.max(IntroRounds.Ease.Floor, rival.Damage * IntroRounds.Ease.Damage ^ n),
		Rate = rival.Rate * IntroRounds.Ease.Rate ^ n,
		Health = math.max(IntroRounds.Ease.HealthFloor, (rival.Health or 1) * IntroRounds.Ease.Health ^ n),
		Lunge = rival.Lunge == true and n == 0,
	}
end

function IntroRounds.looks(round: number)
	local rival = IntroRounds.Rivals[math.clamp(round, 1, IntroRounds.Count)]
	return rival.Looks
end

function IntroRounds.view(state)
	if not state then
		return nil
	end
	local slots = {}
	for i, slot in IntroRounds.Order do
		slots[i] = { Slot = slot, Name = IntroRounds.SlotNames[slot], Piece = state.Pieces[slot] }
	end
	local round = IntroRounds.round(state)
	local rival = IntroRounds.Rivals[round]
	return {
		Won = state.Won,
		Round = round,
		Count = IntroRounds.Count,
		Losses = state.Losses,
		Slots = slots,
		Done = state.Won >= IntroRounds.Count,
		Next = { Name = rival.Name, Title = rival.Title, Slot = IntroRounds.slot(round) },
	}
end

-- Where a new miner's intro is: its 1v1 rounds, the dungeon (the dungeon
-- path only, once the Duels are won) or done.
function IntroRounds.stage(state, dungeon: boolean?): string
	local won = if state then state.Won else IntroRounds.Count
	if won >= IntroRounds.Count then
		return "Done"
	end
	if dungeon and won >= IntroRounds.Duels then
		return "Dungeon"
	end
	return "Duel"
end

-- How many pieces a moment in the intro dungeon pays: its first room
-- ("Room", only as the dungeon's first piece is still to win), the boss
-- ("Boss": whatever's left of the set).
function IntroRounds.dungeonPieces(state, where: string): number
	if not state or state.Won >= IntroRounds.Count then
		return 0
	end
	if where == "Room" then
		return if state.Won < IntroRounds.Duels + IntroRounds.RoomPieces then math.min(IntroRounds.RoomPieces, IntroRounds.Duels + IntroRounds.RoomPieces - state.Won) else 0
	end
	return IntroRounds.Count - state.Won
end

return IntroRounds
