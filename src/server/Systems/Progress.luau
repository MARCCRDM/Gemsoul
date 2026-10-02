--[[
	Season XP and levels. Systems call Progress.addXP(player, "Mine") and
	friends (see Season.XP); a 2x XP boost doubles it. Levelling up tells the
	player; rewards are claimed in the Season Path (StoreServer "ClaimSeason").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = require(ReplicatedStorage.Shared.Season)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Progress = {}

function Progress.addXP(player: Player, reason: string, times: number?)
	local profile = PlayerData.get(player)
	local base = Season.XP[reason]
	if not profile or not base then
		return
	end
	local boosted = os.time() < (profile.Boosts.XPUntil or 0)
	local amount = base * (times or 1) * (if boosted then 2 else 1)
	local before = Season.levelFor(profile.Season.XP)
	profile.Season.XP += amount
	local points = Tree.addXP(profile, base * (times or 1))
	if points > 0 then
		Remotes.Notify:FireClient(
			player,
			string.format(
				"+%d Augment Point%s! Open your Augment Tree with K.",
				points,
				if points == 1 then "" else "s"
			)
		)
	end
	local after = Season.levelFor(profile.Season.XP)
	if after > before then
		Remotes.Notify:FireClient(
			player,
			string.format("LEVEL UP! Season level %d. Claim your reward in the Season Path.", after)
		)
	end
	PlayerData.sync(player)
end

function Progress.level(player: Player): number
	local profile = PlayerData.get(player)
	return if profile then (Season.levelFor(profile.Season.XP)) else 1
end

return Progress
