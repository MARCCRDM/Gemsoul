--[[
	Bring a friend (Shared.Referrals): when someone joins through a player's
	game invite, Roblox tells us who invited them (GetJoinData's
	ReferredByPlayerId). That's recorded against the inviter in a DataStore,
	so it counts even when they're offline or in another server; each friend
	counts once. Once enough friends have joined, the inviter earns the
	reward cosmetic: on their next join, or when they press CHECK CLAIM.

	Request actions:
	  "ReferralState"   refresh from the store, grant the reward if earned;
	                    replies { Count, Needed, Claimed }
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ReferralRules = require(ReplicatedStorage.Shared.Referrals)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local Referrals = {}

local store = nil
local function referralStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("Referrals_v1")
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

-- Grants the reward when it's earned; stores the count on the profile.
local function settle(player: Player): (boolean, number?)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return false, nil
	end
	local count = countFor(player.UserId)
	profile.Referrals = profile.Referrals or { Count = 0 }
	if count then
		profile.Referrals.Count = math.max(profile.Referrals.Count or 0, count)
	end
	local reward = Cosmetics.List[ReferralRules.Reward]
	local granted = false
	if reward and ReferralRules.earned(profile.Referrals.Count) and not profile.Cosmetics.Owned[reward.Id] then
		profile.Cosmetics.Owned[reward.Id] = true
		profile.Referrals.ClaimedAt = os.time()
		granted = true
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
	local isNew = false
	pcall(function()
		data:UpdateAsync(tostring(referrerId), function(entry)
			local updated, fresh = ReferralRules.record(entry, friendId)
			isNew = fresh
			return updated
		end)
	end)
	-- The inviter is here: they get it now.
	local referrer = Players:GetPlayerByUserId(referrerId)
	if isNew and referrer then
		settle(referrer)
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
	local claimed = profile.Cosmetics.Owned[ReferralRules.Reward] == true
	local reward = Cosmetics.List[ReferralRules.Reward]
	local message = if granted
		then string.format("%s unlocked! Find them in the Store under Backs.", reward and reward.Name or "Reward")
		elseif claimed then "Already yours. Thanks for bringing a friend!"
		else "Not yet: your invited friend needs to join. It unlocks automatically."
	return reply(claimed, message, { Count = count, Needed = ReferralRules.Needed, Claimed = claimed })
end

function Referrals.start()
	Shop.register("ReferralState", state)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerAdded:Connect(onJoin)
end

return Referrals
