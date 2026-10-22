--[[
	Season XP and your level. Systems call Progress.addXP(player, "Sell") and
	friends (see Season.XP): the same XP for the Season Path and your level
	(Shared.AugmentTree); a 2x XP boost doubles the Season's.

	Your level comes mostly from wins (Shared.Levelling):
	  Progress.won(player, kind, foe, season?, rival?) -> XP
	      a win of `kind` (Levelling.Share) over a foe at level `foe`: worth
	      a share of your own level, more for a higher foe, less for a lower;
	      `season` what the Season Path pays for it (Season.XP), if anything;
	      `rival` the Player beaten, if one (beaten again soon, worth less)
	  Progress.mined(player) -> XP
	      a rock broken: less and less the more you've mined lately (the
	      Season's too), never your kaiju's (KaijuServer)
	  Progress.levelOf(player) -> your level
	Levelling up tells the player; Season rewards are claimed in the Season
	Path (StoreServer "ClaimSeason").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = require(ReplicatedStorage.Shared.Season)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Levelling = require(ReplicatedStorage.Shared.Levelling)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Progress = {}

-- (For tests: the clock the mining and the "beaten again" counts go by.)
Progress.now = function(): number
	return os.time()
end

-- `season` Season XP (doubled by a boost) and `level` XP for your level.
local function give(player: Player, profile, season: number, level: number)
	local boosted = os.time() < (profile.Boosts.XPUntil or 0)
	local before = Season.levelFor(profile.Season.XP)
	profile.Season.XP += season * (if boosted then 2 else 1)
	local points = Tree.addXP(profile, level)
	if points > 0 then
		-- Seen by everyone near (the light over you), with your banner and
		-- what it brought (LevelUpFx).
		local reached = Tree.level(profile.Augments.XP)
		Remotes.CombatFx:FireAllClients(
			"LevelUp",
			player.Character or player,
			reached,
			"Miner",
			nil,
			player.DisplayName,
			string.format(
				"+%d augment point%s, +%d max health. Spend points with K.",
				points,
				if points == 1 then "" else "s",
				points * Tree.VitalsPerLevel.Health
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

function Progress.addXP(player: Player, reason: string, times: number?)
	local profile = PlayerData.get(player)
	local base = Season.XP[reason]
	if not profile or not base then
		return
	end
	local amount = base * (times or 1)
	give(player, profile, amount, amount)
end

function Progress.levelOf(player: Player): number
	local profile = PlayerData.get(player)
	return Tree.level(profile and profile.Augments and profile.Augments.XP or 0)
end

-- Who each player has beaten lately: [player][their UserId] = { times }.
local beaten: { [Player]: { [number]: { number } } } = setmetatable({}, { __mode = "k" }) :: any

local function againstRival(player: Player, rival: Player?): number
	if not rival or rival == player then
		return 0
	end
	local now = Progress.now()
	local mine = beaten[player] or {}
	beaten[player] = mine
	local times = {}
	for _, at in mine[rival.UserId] or {} do
		if now - at < Levelling.Again.Window then
			table.insert(times, at)
		end
	end
	table.insert(times, now)
	mine[rival.UserId] = times
	return #times - 1
end

function Progress.won(player: Player, kind: string, foe: number?, season: string?, rival: Player?): number
	local profile = PlayerData.get(player)
	if not profile or not Levelling.Share[kind] then
		return 0
	end
	local level = Tree.level(profile.Augments and profile.Augments.XP or 0)
	local again = againstRival(player, rival)
	local amount = if level >= Tree.MaxLevel
		then 0
		else Levelling.winXP(kind, level, foe, Tree.xpToNext(level), again)
	give(player, profile, if season then Season.XP[season] or 0 else 0, amount)
	return amount
end

function Progress.mined(player: Player): number
	local profile = PlayerData.get(player)
	if not profile then
		return 0
	end
	local now = Progress.now()
	local lately = (profile :: any).Levelling or {}
	local mined = Levelling.rested(lately.Mined, now - (tonumber(lately.At) or now))
	local amount = Levelling.mineXP(mined)
	;(profile :: any).Levelling = { Mined = mined + 1, At = now }
	give(player, profile, amount, amount)
	return amount
end

function Progress.level(player: Player): number
	local profile = PlayerData.get(player)
	return if profile then (Season.levelFor(profile.Season.XP)) else 1
end

return Progress
