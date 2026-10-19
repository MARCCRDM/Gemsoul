--[[
	Reward coupons (Shared.Coupons): spending them. Every friend who joins on
	your invite gives one of each (Systems/Referrals); the coupons menu (the
	lobby's INVITE tile: ReferralUI) spends them, one at a time.

	Request actions:
	  "UseCoupon", kind   spend one. Swings: half your pick's free charge back
	                      (Shared.SwingRestore.Coupon; refused, and kept,
	                      while it's full). Revive: every kaiju of yours that's
	                      knocked out back now (refused, kept, while none is).
	                      XPBoost: 30 minutes of double XP. Replies
	                      { Kind, Left } (how many of that kind are left).

	Wired in by Main (each nil while its part of the game is off):
	  CouponServer.restoreSwings(player, share) -> swings added (OutpostServer.restoreSwings)
	  CouponServer.reviveKaiju(player)          -> kaiju revived (KaijuServer.reviveAll)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coupons = require(ReplicatedStorage.Shared.Coupons)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local StoreServer = require(script.Parent.StoreServer)

local reply = Shop.reply

local CouponServer = {}
CouponServer.restoreSwings = nil :: ((Player, number) -> number)?
CouponServer.reviveKaiju = nil :: ((Player) -> number)?

local function use(player: Player, kind: any)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Profile unavailable.")
	end
	local rule = type(kind) == "string" and Coupons.Kinds[kind]
	if not rule then
		return reply(false, "That isn't a coupon.")
	end
	if Coupons.count(profile, kind) <= 0 then
		return reply(false, string.format("You have no %s coupons. Invite a friend for more!", rule.Name))
	end
	local message
	if kind == "Swings" then
		local added = if CouponServer.restoreSwings then CouponServer.restoreSwings(player, SwingRestore.Coupon) else 0
		if added <= 0 then
			return reply(false, "Your pick's swings are full: keep it for when they run low.")
		end
		message = string.format("+%d swings!", added)
	elseif kind == "Revive" then
		local revived = if CouponServer.reviveKaiju then CouponServer.reviveKaiju(player) else 0
		if revived <= 0 then
			return reply(false, "None of your kaiju is knocked out: keep it for when one is.")
		end
		message = if revived == 1 then "Your kaiju is back on its feet!" else string.format("%d kaiju back on their feet!", revived)
	else
		StoreServer.grant(player, { XPBoostMinutes = rule.Minutes })
		message = string.format("Double XP for %d minutes!", rule.Minutes)
	end
	Coupons.take(profile, kind)
	PlayerData.sync(player)
	return reply(true, message, { Kind = kind, Left = Coupons.count(profile, kind) })
end

function CouponServer.start()
	Shop.register("UseCoupon", use)
end

CouponServer._use = use

return CouponServer
