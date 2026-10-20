-- Rolls new gemstones (GemRoller: element, rarity, surge, metrics). Pure logic
-- with no Roblox services, so it can be tested outside the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)

local GemGenerator = {}

type Gem = GemConfig.Gem

--[[
	Recovers a naturally faceted, enchant-ready gemstone.
	source: "MiningNode" | "MiningStore" | "PvEDrop" | "PvPWager"
	opts.Luck: extra luck on top of the source's own (0-1)
	opts.Id: unique id (the server passes a GUID)
	opts.Home, opts.Bias: mined in one of the Outpost's biomes, its element
	  (Home) comes up Bias of the time (Shared.Frontier.Biome)
]]
function GemGenerator.generate(
	rng: Random,
	source: string,
	opts: {
		Luck: number?,
		Id: string,
		Time: number,
		Rarity: string?,
		Home: string?,
		Bias: number?,
	}
): Gem
	local luck = math.clamp((GemConfig.SourceLuck[source] or 0) + (opts.Luck or 0), 0, 1)
	-- Element, rarity, surge tier, surge rank and metrics (GemRoller).
	-- (opts.Rarity sets the rarity: an Arena Cache's Legendaries; a mined
	-- gem rolls mostly Commons, GemRoller.MiningWeights.)
	local base = if GemRoller.MinedSources[source] then GemRoller.MiningWeights else nil
	local rolled = GemRoller.roll(rng, luck, opts.Rarity, base, opts.Home, opts.Bias)
	return {
		Id = opts.Id,
		Element = rolled.Element,
		Tier = rolled.Tier,
		Surge = rolled.Surge,
		-- One Offense, one Ability and one Defense (the Q / E / R triad).
		Traits = rolled.Traits,
		SurgeTier = rolled.SurgeTier,
		SurgeRank = rolled.SurgeRank,
		Clarity = rolled.Clarity,
		Size = rolled.Size,
		Cut = rolled.Cut,
		CutMethod = "Natural",
		Source = if source == "VipMiningNode" then "MiningNode" else source,
		Found = opts.Time,
	}
end

return GemGenerator
