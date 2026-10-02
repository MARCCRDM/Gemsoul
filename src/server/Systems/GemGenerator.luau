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
]]
function GemGenerator.generate(rng: Random, source: string, opts: { Luck: number?, Id: string, Time: number }): Gem
	local luck = math.clamp((GemConfig.SourceLuck[source] or 0) + (opts.Luck or 0), 0, 1)
	-- Element, rarity, surge tier, surge rank and metrics (GemRoller).
	local rolled = GemRoller.roll(rng, luck)
	return {
		Id = opts.Id,
		Element = rolled.Element,
		Tier = rolled.Tier,
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
