--[[
	Bring friends: invite them (Roblox's own game invite) and, as they join
	through it, you climb a ladder of exclusive cosmetics, never sold:
	  1 friend   Kindred Edge (Legendary weapon skin, only from here)
	  2 friends  Twin Star (pickaxe)
	  3 friends  Crusader's Standard (back piece)
	  4 friends  Crusader Gold (weapon skin)
	  5 friends  Crusader Plate (armor suit)
	  10 friends CRUSADER LEGEND (title over your head)
	Pure, for the server (Systems/Referrals), the client (Modules/ReferralUI,
	the Shop's Free tab) and tests.

	  Referrals.Tiers                     { Friends, Reward } from the first
	  Referrals.Reward / Needed           the first tier (older callers)
	  Referrals.rewardsFor(count)         -> every reward earned at `count`
	  Referrals.nextTier(count)           -> the next tier to reach, or nil
	  Referrals.referrer(joinData, userId) -> the inviter's UserId, or nil
	                                       (no invite, or your own)
	  Referrals.record(entry, friendId)   -> entry, isNew: counts a friend
	                                       once, however often they rejoin
	  Referrals.earned(count)             -> enough friends joined?
]]
local Referrals = {}

Referrals.Tiers = {
	{ Friends = 1, Reward = "SkinKindred" },
	{ Friends = 2, Reward = "PickTwinStar" },
	{ Friends = 3, Reward = "BackStandard" },
	{ Friends = 4, Reward = "SkinCrusader" },
	{ Friends = 5, Reward = "SuitCrusader" },
	{ Friends = 10, Reward = "TitleLegend" },
}
Referrals.Reward = Referrals.Tiers[1].Reward
Referrals.Needed = Referrals.Tiers[1].Friends

function Referrals.rewardsFor(count: number): { string }
	local rewards = {}
	for _, tier in Referrals.Tiers do
		if (count or 0) >= tier.Friends then
			table.insert(rewards, tier.Reward)
		end
	end
	return rewards
end

function Referrals.nextTier(count: number)
	for _, tier in Referrals.Tiers do
		if (count or 0) < tier.Friends then
			return tier
		end
	end
	return nil
end

function Referrals.referrer(joinData, userId: number): number?
	local id = type(joinData) == "table" and joinData.ReferredByPlayerId or nil
	if type(id) ~= "number" or id <= 0 or id ~= id or math.floor(id) ~= id or id == userId then
		return nil
	end
	return id
end

-- A stored record: { Friends = { [userId string] = true }, Count = n }.
function Referrals.record(entry, friendId: number)
	local clean = { Friends = {}, Count = 0 }
	if type(entry) == "table" and type(entry.Friends) == "table" then
		for key, value in entry.Friends do
			if value == true and type(key) == "string" then
				clean.Friends[key] = true
				clean.Count += 1
			end
		end
	end
	local key = tostring(friendId)
	if clean.Friends[key] then
		return clean, false
	end
	clean.Friends[key] = true
	clean.Count += 1
	return clean, true
end

function Referrals.earned(count: number?): boolean
	return (count or 0) >= Referrals.Needed
end

return Referrals
