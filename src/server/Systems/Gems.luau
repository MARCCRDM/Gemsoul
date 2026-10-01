--[[
	The one place gems enter the game. Every source calls Gems.award:
	  "MiningNode"   mining a node in the quarry (uses the free quota)
	  "VipMiningNode" mining a node in the VIP pit (luckier rolls)
	  "MiningStore"  legacy store / expedition cache rewards
	  "PvEDrop"      monster loot; pass opts.Luck for tougher monsters
	PvP wagers don't create gems: they move existing ones with
	PlayerData.transferGem.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemGenerator = require(script.Parent.GemGenerator)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Gems = {}

local rng = Random.new()

-- Recovers an enchant-ready gem for the player. Returns the gem, or nil if their
-- inventory is full.
function Gems.award(player: Player, source: string, opts: { Luck: number? }?): GemConfig.Gem?
	local gem = GemGenerator.generate(rng, source, {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Luck = opts and opts.Luck,
	})
	if not PlayerData.addGem(player, gem) then
		Remotes.Notify:FireClient(player, "Your gem pouch is full! Sell or use some gems first.")
		return nil
	end
	Remotes.Notify:FireClient(
		player,
		string.format(
			"Found: %s  |  Size %d, Clarity %d  |  worth ~%d coins",
			GemConfig.displayName(gem),
			gem.Size,
			gem.Clarity,
			GemConfig.value(gem)
		)
	)
	return gem
end

-- PvE hook: call when a monster dies. `luck` 0-1 scales with monster toughness.
function Gems.dropFromMonster(player: Player, luck: number): GemConfig.Gem?
	return Gems.award(player, "PvEDrop", { Luck = math.clamp(luck, 0, 1) })
end

function Gems.random(): Random
	return rng
end

return Gems
