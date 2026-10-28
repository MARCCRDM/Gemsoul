--[[
	Reward coupons: every friend who joins on your invite (Shared.Referrals)
	gives you one of each (PerFriend). They wait on your profile
	(profile.Coupons) till you use them, from the coupons menu (the lobby's
	INVITE tile: ReferralUI). One coupon, one use.

	  Swings    SWING RESTORE: half your pick's free charge back
	            (SwingRestore.Coupon; not used while it's full)
	  Revive    KAIJU REVIVE: every kaiju of yours that's knocked out back
	            on its feet now (not used while none is)
	  XPBoost   DOUBLE XP: 30 minutes of double XP

	Pure, for the server (Systems/CouponServer, Systems/Referrals), the
	client and tests.

	  Coupons.Kinds[kind] / Coupons.Order
	  Coupons.PerFriend               { [kind] = n } for each friend who joins
	  Coupons.count(profile, kind)    -> how many you have
	  Coupons.total(profile)          -> how many of every kind
	  Coupons.add(profile, kind, n)   -> the new count
	  Coupons.take(profile, kind)     -> true if one was spent
	  Coupons.owed(friends, paid)     -> { [kind] = n } for the friends not
	                                     paid for yet, and the new paid count
]]
local Coupons = {}

Coupons.Kinds = {
	Swings = {
		Name = "Swing Restore",
		Short = "SWINGS",
		Text = "Half your pick's swings back.",
		Color = Color3.fromRGB(255, 196, 74),
	},
	Revive = {
		Name = "Kaiju Revive",
		Short = "REVIVE",
		Text = "Your knocked-out kaiju back now.",
		Color = Color3.fromRGB(255, 104, 96),
	},
	XPBoost = {
		Name = "Double XP",
		Short = "XP BOOST",
		Text = "Double XP for 30 minutes.",
		Color = Color3.fromRGB(176, 132, 255),
		Minutes = 30,
	},
}
Coupons.Order = { "Swings", "Revive", "XPBoost" }
-- Off for now: no coupons for friends who join, and no COUPONS tab. (A
-- Revive coupon bought with Robux while none of your kaiju was down still
-- waits for you, and the kaiju panel's COUPON still spends it.)
Coupons.Enabled = false
Coupons.PerFriend = { Swings = 1, Revive = 1, XPBoost = 1 }
-- (No more than this of one kind waits on a profile.)
Coupons.Most = 99

function Coupons.count(profile, kind: string): number
	local held = type(profile) == "table" and profile.Coupons
	local n = type(held) == "table" and held[kind]
	return if type(n) == "number" and n > 0 then math.floor(n) else 0
end

function Coupons.total(profile): number
	local n = 0
	for _, kind in Coupons.Order do
		n += Coupons.count(profile, kind)
	end
	return n
end

function Coupons.add(profile, kind: string, n: number?): number
	if not Coupons.Kinds[kind] then
		return 0
	end
	profile.Coupons = if type(profile.Coupons) == "table" then profile.Coupons else {}
	local count = math.min(Coupons.Most, Coupons.count(profile, kind) + math.max(0, math.floor(n or 1)))
	profile.Coupons[kind] = count
	return count
end

function Coupons.take(profile, kind: string): boolean
	local n = Coupons.count(profile, kind)
	if n <= 0 then
		return false
	end
	profile.Coupons[kind] = if n > 1 then n - 1 else nil
	return true
end

function Coupons.owed(friends: number, paid: number?): ({ [string]: number }, number)
	friends, paid = math.max(0, math.floor(friends or 0)), math.max(0, math.floor(paid or 0))
	local owed = {}
	local new = friends - paid
	if new > 0 then
		for kind, n in Coupons.PerFriend do
			owed[kind] = n * new
		end
	end
	return owed, math.max(friends, paid)
end

return Coupons
