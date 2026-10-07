--[[
	Bring a friend: invite a friend (Roblox's own game invite) and, once they
	join through it, you earn an exclusive weapon, the Crusader's Standard. Pure, for the server
	(Systems/Referrals), the client (Modules/ReferralUI) and tests.

	  Referrals.Reward                    the weapon you earn (a Weapons id)
	  Referrals.Needed                    friends who must join through you
	  Referrals.referrer(joinData, userId) -> the inviter's UserId, or nil
	                                       (no invite, or your own)
	  Referrals.record(entry, friendId)   -> entry, isNew: counts a friend
	                                       once, however often they rejoin
	  Referrals.earned(count)             -> enough friends joined?
]]
local Referrals = {}

Referrals.Reward = "CrusaderStandard"
Referrals.Needed = 1

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
