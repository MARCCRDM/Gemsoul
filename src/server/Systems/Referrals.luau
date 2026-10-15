--[[
	Bring a friend (Shared.Referrals): when someone joins through a player's
	game invite, Roblox tells us who invited them (GetJoinData's
	ReferredByPlayerId). That's recorded against the inviter in a DataStore,
	so it counts even when they're offline or in another server; each friend
	counts once (a failed save is tried again). Once enough friends have
	joined, the inviter earns the rewards of every tier reached
	(Shared.Referrals.Tiers) and wears them: at once if they're in this
	server, at once in theirs if they're in another (a cross-server message,
	MessagingService), else on their next join or CHECK CLAIM.

	Request actions:
	  "ReferralState"   refresh from the store, grant the reward if earned;
	                    replies Ok (the check worked) and { Count, Needed,
	                    Claimed (the first reward is yours) }
]]
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ReferralRules = require(ReplicatedStorage.Shared.Referrals)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local Referrals = {}

-- The cross-server message: a friend joined through this inviter's invite.
Referrals.Topic = "GemsoulReferralJoined"
Referrals.SaveTries = 3

local store = nil
local function referralStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStoreName .. "_Referrals")
		end)
		store = if ok then result else false
	end
	return store or nil
end

-- How many friends have joined through `userId`'s invites (nil if unknown).
local function countFor(userId: number): number?
	local data = referralStore()
	if not data then
		return nil
	end
	local ok, entry = pcall(function()
		return data:GetAsync(tostring(userId))
	end)
	if not ok then
		return nil
	end
	return if type(entry) == "table" and type(entry.Count) == "number" then entry.Count else 0
end

local function ownsReward(profile): boolean
	return profile.Cosmetics ~= nil and profile.Cosmetics.Owned[ReferralRules.Reward] == true
end

-- Grants the reward when it's earned; stores the count on the profile.
-- `known`: a count just reported (a friend's join, here or in another
-- server), trusted over a read that may still be cached.
local function settle(player: Player, known: number?): (any, number?)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return false, nil
	end
	local count = countFor(player.UserId)
	profile.Referrals = profile.Referrals or { Count = 0 }
	if count then
		profile.Referrals.Count = math.max(profile.Referrals.Count or 0, count)
	end
	if type(known) == "number" and known == known then
		profile.Referrals.Count = math.max(profile.Referrals.Count or 0, math.floor(known))
	end
	-- Every tier reached (Referrals.Tiers) that isn't yours yet; each goes
	-- straight on, to show it off.
	local granted = nil
	for _, id in ReferralRules.rewardsFor(profile.Referrals.Count) do
		local reward = Cosmetics.get(id)
		if reward and not profile.Cosmetics.Owned[id] then
			profile.Cosmetics.Owned[id] = true
			PlayerData.setCosmetic(player, reward.Kind, reward.Id)
			profile.Referrals.ClaimedAt = os.time()
			granted = reward
		end
	end
	PlayerData.sync(player)
	return granted, count
end

-- A friend joined through `referrerId`'s invite: count them (once).
local function recordJoin(referrerId: number, friendId: number)
	local data = referralStore()
	if not data then
		return
	end
	local isNew, count, saved = false, nil, false
	for try = 1, Referrals.SaveTries do
		saved = pcall(function()
			data:UpdateAsync(tostring(referrerId), function(entry)
				local updated, fresh = ReferralRules.record(entry, friendId)
				isNew, count = fresh, updated.Count
				return updated
			end)
		end)
		if saved then
			break
		end
		task.wait(try * 2)
	end
	if not saved or not isNew then
		return
	end
	local referrer = Players:GetPlayerByUserId(referrerId)
	if referrer then
		-- The inviter is here: they get it now.
		settle(referrer, count)
	else
		-- Maybe in another server: tell it, so they get it there now.
		pcall(function()
			MessagingService:PublishAsync(Referrals.Topic, { Referrer = referrerId, Count = count })
		end)
	end
end

local function onJoin(player: Player)
	-- (Wait for the profile: the reward lands on it.)
	local waited = 0
	while player.Parent and not PlayerData.get(player) and waited < 30 do
		waited += task.wait(0.5)
	end
	if not player.Parent then
		return
	end
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local referrerId = ok and ReferralRules.referrer(joinData, player.UserId) or nil
	if referrerId then
		recordJoin(referrerId, player.UserId)
	end
	-- Friends may have joined through your invites while you were away.
	settle(player)
end

local function state(player: Player)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return reply(false, "Profile unavailable.")
	end
	local granted = settle(player)
	local count = profile.Referrals and profile.Referrals.Count or 0
	local claimed = ownsReward(profile)
	local nextTier = ReferralRules.nextTier(count)
	local message = if granted
		then string.format("%s unlocked and equipped!", granted.Name)
		elseif nextTier then string.format(
			"%d / %d friends joined. The next reward unlocks automatically.",
			count,
			nextTier.Friends
		)
		else "Every reward is yours. Thanks for bringing your friends!"
	-- (The check itself worked: Ok. Whether the reward is yours yet is Claimed.)
	return reply(true, message, { Count = count, Needed = ReferralRules.Needed, Claimed = claimed })
end

-- Another server recorded a friend's join for someone who may be here.
function Referrals.onMessage(message)
	local data = type(message) == "table" and message.Data or nil
	local referrerId = type(data) == "table" and data.Referrer or nil
	local referrer = type(referrerId) == "number" and Players:GetPlayerByUserId(referrerId) or nil
	if referrer then
		settle(referrer, data.Count)
	end
end

function Referrals.start()
	Shop.register("ReferralState", state)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(Referrals.Topic, Referrals.onMessage)
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerAdded:Connect(onJoin)
end

return Referrals
