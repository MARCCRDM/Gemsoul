--[[
	Free cosmetics for growing the game (Shared.FreeRewards): joining the
	Roblox group, promo codes (Systems/Codes) and the 7-day login streak
	(granted where the streak is counted, in PlayerData). Bringing friends
	is Systems/Referrals.

	Request actions:
	  "FreeRewards"        everything the Free tab shows: group, invites,
	                       streak, codes used
	  "CheckGroup"         are you in the group now? grants the skin if so
	  "RedeemCode", text   a promo code
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Rules = require(ReplicatedStorage.Shared.FreeRewards)
local Referrals = require(ReplicatedStorage.Shared.Referrals)
local Codes = require(script.Parent.Codes)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local StoreServer = require(script.Parent.StoreServer)

local reply = Shop.reply

local FreeRewards = {}

local function owns(profile, id: string): boolean
	return profile.Cosmetics.Owned[id] == true
end

-- Gives a free cosmetic and puts it on, so it's seen straight away.
function FreeRewards.give(player: Player, id: string): boolean
	local profile = PlayerData.get(player)
	local cosmetic = Cosmetics.get(id)
	if not profile or not cosmetic or owns(profile, id) then
		return false
	end
	profile.Cosmetics.Owned[id] = true
	PlayerData.setCosmetic(player, cosmetic.Kind, id)
	return true
end

local function inGroup(player: Player): boolean
	if not Rules.groupEnabled() then
		return false
	end
	local ok, member = pcall(function()
		return player:IsInGroup(Rules.Group.Id)
	end)
	return ok and member == true
end

local function checkGroup(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Try again in a moment.")
	end
	if not Rules.groupEnabled() then
		return reply(false, "The group reward is coming soon.")
	end
	local reward = Cosmetics.get(Rules.Group.Reward)
	if owns(profile, Rules.Group.Reward) then
		return reply(true, "Already yours. Thanks for joining!")
	end
	if not inGroup(player) then
		return reply(false, "Join the group first, then check again.")
	end
	FreeRewards.give(player, Rules.Group.Reward)
	return reply(true, string.format("%s unlocked and equipped!", reward and reward.Name or "Reward"))
end

-- One try every 2 seconds, so codes can't be guessed by brute force.
local lastTry: { [Player]: number } = {}
local function redeem(player: Player, text: any)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return reply(false, "Try again in a moment.")
	end
	local now = os.clock()
	if lastTry[player] and now - lastTry[player] < 2 then
		return reply(false, "Slow down: one code at a time.")
	end
	lastTry[player] = now
	local code = Rules.normalizeCode(text)
	local entry, why = Codes.find(code, os.time(), player)
	if not entry then
		return reply(false, why or "That code doesn't exist.")
	end
	profile.Codes = profile.Codes or {}
	if profile.Codes[code] then
		return reply(false, "You've already used that code.")
	end
	profile.Codes[code] = os.time()
	-- A cosmetic from a code goes straight on, like the other free ones.
	for _, id in entry.Reward.Cosmetics or {} do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and not owns(profile, id) then
			profile.Cosmetics.Owned[id] = true
			PlayerData.setCosmetic(player, cosmetic.Kind, id)
		end
	end
	local rest = table.clone(entry.Reward)
	rest.Cosmetics = nil
	local lines = StoreServer.grant(player, rest, "Code")
	for _, id in entry.Reward.Cosmetics or {} do
		table.insert(lines, 1, Cosmetics.get(id) and Cosmetics.get(id).Name or id)
	end
	PlayerData.sync(player)
	return reply(true, "Code " .. code .. ": " .. table.concat(lines, ", "), { Lines = lines })
end

local function state(player: Player)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return reply(false, "Try again in a moment.")
	end
	local count = profile.Referrals and profile.Referrals.Count or 0
	local tiers = {}
	for _, tier in Referrals.Tiers do
		table.insert(tiers, { Friends = tier.Friends, Reward = tier.Reward, Owned = owns(profile, tier.Reward) })
	end
	local used = 0
	for _ in profile.Codes or {} do
		used += 1
	end
	return reply(true, "", {
		Group = {
			Enabled = Rules.groupEnabled(),
			Id = Rules.Group.Id,
			Reward = Rules.Group.Reward,
			Owned = owns(profile, Rules.Group.Reward),
		},
		Invites = { Count = count, Tiers = tiers },
		Streak = {
			Days = Rules.Streak.Days,
			Streak = profile.Daily and profile.Daily.Streak or 0,
			Reward = Rules.Streak.Reward,
			Owned = owns(profile, Rules.Streak.Reward),
		},
		CodesUsed = used,
	})
end

local function onJoin(player: Player)
	-- Already in the group: the skin arrives with no button to press.
	local waited = 0
	while player.Parent and not PlayerData.get(player) and waited < 30 do
		waited += task.wait(0.5)
	end
	local profile = PlayerData.get(player)
	if profile and not owns(profile, Rules.Group.Reward) and inGroup(player) then
		FreeRewards.give(player, Rules.Group.Reward)
	end
end

function FreeRewards.start()
	Shop.register("FreeRewards", state)
	Shop.register("CheckGroup", checkGroup)
	Shop.register("RedeemCode", redeem)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return FreeRewards
