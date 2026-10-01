local profiles = {}
local tradeLocks = {}
local PlayerData = {
 canTrade = function() return true end,
 isTradeLocked = function(player) return tradeLocks[player] == true end,
 setTradeLocked = function(player, value) tradeLocks[player] = value end,
 suspendSaving = function() end,
 save = function() end,
 get = function(player) return profiles[player] end,
 sync = function() end,
 snapshot = function(player) return profiles[player] end,
 equipGear = function() return true end,
 milestone = function() end,
 setIntroFlag = function() end,
 newGemId = function() guid += 1; return "gem-" .. guid end,
}
function PlayerData.setGearQuality(player, kind, id, quality)
 profiles[player].Owned[kind][id] = quality
 GearRolls.ensure(profiles[player], Random.new())
end
function PlayerData.addCoins(player, coins) profiles[player].Coins += coins end
function PlayerData.addGem(player, gem)
 if #profiles[player].Gems >= Config.MaxGems then return false end
 table.insert(profiles[player].Gems, gem)
 return true
end
function PlayerData.findGem(player, id)
 for _, gem in profiles[player].Gems do if gem.Id == id then return gem end end
end
function PlayerData.removeGem(player, id)
 for i, gem in profiles[player].Gems do if gem.Id == id then return table.remove(profiles[player].Gems, i) end end
end
local rng = Random.new(934)
local Gems = {random = function() return rng end}
function Gems.award(player, source, opts)
 local gem = GemGenerator.generate(rng, source, {Id = PlayerData.newGemId(), Time = 1, Luck = opts and opts.Luck})
 return if PlayerData.addGem(player, gem) then gem else nil
end
