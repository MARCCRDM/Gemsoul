-- lune run tests/rewards_cases.luau <repo>
-- Swing restores and reward coupons: the arena tournament's shares
-- (Shared.SwingRestore: 1st, 5th and 10th win; never past full; casual
-- runs), the coupons (Shared.Coupons: per friend, once, add/take), spending
-- them (Systems/CouponServer: refused and kept when it would do nothing),
-- and the kaiju revive product (Shared.Store: only with one down).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
local parent = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	UDim2 = roblox.UDim2,
	CFrame = roblox.CFrame,
	Enum = roblox.Enum,
	script = { Parent = parent },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local SwingRestore = shared("SwingRestore")
local Coupons = shared("Coupons")
local Store = shared("Store")

-- The tournament's shares ---------------------------------------------------
check(SwingRestore.Tournament == 10, "A tournament is ten wins")
check(SwingRestore.streakShare(1) == 0.10, "The first win restores 10%")
check(SwingRestore.streakShare(5) == 0.25, "The fifth win restores 25%")
check(SwingRestore.streakShare(10) == 0.50, "The tenth win restores 50%")
for _, n in { 0, 2, 3, 4, 6, 7, 8, 9 } do
	check(SwingRestore.streakShare(n) == 0, "Win " .. n .. " restored swings")
end
check(SwingRestore.streakShare(11) == 0.10 and SwingRestore.round(11) == 1, "The 11th win isn't the next tournament's first")
check(SwingRestore.streakShare(20) == 0.50 and SwingRestore.won(20) and not SwingRestore.won(19), "The second tournament won")
check(SwingRestore.won(10) and not SwingRestore.won(9) and not SwingRestore.won(0), "Ten in a row wins it")
local at, share = SwingRestore.next(1)
check(at == 5 and share == 0.25, "After the first win, the fifth is next")
at, share = SwingRestore.next(5)
check(at == 10 and share == 0.50, "After the fifth, the tenth")
at, share = SwingRestore.next(10)
check(at == 11 and share == 0.10, "After a tournament, a new one's first")
at, share = SwingRestore.next(0)
check(at == 1 and share == 0.10, "A fresh run's first win")
check(SwingRestore.Dungeon == 0.25 and SwingRestore.Coupon == 0.50, "Dungeon and coupon shares")
-- Never past full, nothing when full (or over, from a refill).
local swings, added = SwingRestore.apply(100, 0.10, 600)
check(swings == 160 and added == 60, "10% of 600 is 60")
swings, added = SwingRestore.apply(580, 0.50, 600)
check(swings == 600 and added == 20, "A restore went past full")
swings, added = SwingRestore.apply(600, 0.50, 600)
check(swings == 600 and added == 0, "A full pick was restored")
swings, added = SwingRestore.apply(900, 0.25, 600)
check(swings == 900 and added == 0, "A refilled pick lost swings to a restore")
swings, added = SwingRestore.apply(0, 0, 600)
check(swings == 0 and added == 0, "No share, no swings")
-- A casual run: a win adds, the same foe twice running doesn't, a loss ends it.
local duel = {}
local streak, counted = SwingRestore.casual(duel, true, 7)
check(streak == 1 and counted and duel.CasualLastBeaten == 7, "A casual win")
streak, counted = SwingRestore.casual(duel, true, 7)
check(streak == 1 and not counted, "The same foe twice running counted")
streak, counted = SwingRestore.casual(duel, true, 8)
check(streak == 2 and counted, "A new foe")
streak, counted = SwingRestore.casual(duel, false, 9)
check(streak == 0 and not counted and duel.CasualStreak == 0 and duel.CasualLastBeaten == nil, "A loss didn't end the run")

-- Coupons -------------------------------------------------------------------------
for _, kind in Coupons.Order do
	local rule = Coupons.Kinds[kind]
	check(rule and rule.Name and rule.Short and rule.Text and rule.Color, kind .. " isn't described")
	check((Coupons.PerFriend[kind] or 0) >= 1, kind .. " isn't given per friend")
end
check(#Coupons.Order == 3 and Coupons.Kinds.XPBoost.Minutes == 30, "Three kinds; 30 minutes of double XP")
local profile = {}
check(Coupons.count(profile, "Swings") == 0 and Coupons.total(profile) == 0, "No coupons to start")
check(not Coupons.take(profile, "Swings"), "Took a coupon from none")
check(Coupons.add(profile, "Swings", 2) == 2 and Coupons.add(profile, "Revive") == 1, "Adding coupons")
check(Coupons.add(profile, "Nonsense", 3) == 0 and profile.Coupons.Nonsense == nil, "A coupon kind that doesn't exist")
check(Coupons.total(profile) == 3, "Total")
check(Coupons.take(profile, "Revive") and profile.Coupons.Revive == nil, "The last one taken leaves nothing")
check(Coupons.take(profile, "Swings") and Coupons.count(profile, "Swings") == 1, "Taking one of two")
check(Coupons.add(profile, "XPBoost", 500) == Coupons.Most, "Capped")
-- Owed per friend, once.
local owed, paid = Coupons.owed(2, nil)
check(owed.Swings == 2 and owed.Revive == 2 and owed.XPBoost == 2 and paid == 2, "Two friends, two of each")
owed, paid = Coupons.owed(2, 2)
check(next(owed) == nil and paid == 2, "Paid twice for the same friends")
owed, paid = Coupons.owed(3, 2)
check(owed.Swings == 1 and paid == 3, "A third friend")
owed, paid = Coupons.owed(1, 3)
check(next(owed) == nil and paid == 3, "A count read lower than paid took coupons back")

-- The kaiju revive product (Shared.Store) -------------------------------------------
check(Store.RobuxProducts.KaijuRevive ~= nil and Store.robuxPrice("KaijuRevive") == 25, "The revive's product and price")
check(Store.productName("KaijuRevive") == "Kaiju Revive", "The revive's name")
check(Store.contents("KaijuRevive") and Store.contents("KaijuRevive").KaijuRevive, "The revive's contents")
local up = { Kaiju = { List = { k1 = { Id = "k1", Level = 3 } } }, Cosmetics = { Owned = {} } }
local okBuy, why = Store.canBuy("KaijuRevive", up, 0)
check(not okBuy and why and string.find(why, "knocked out", 1, true), "A revive sold with none down")
up.Kaiju.List.k1.Down = true
check(Store.canBuy("KaijuRevive", up, 0), "A revive not sold with one down")

-- Spending coupons (Systems/CouponServer), with stand-ins for what it calls ------
local profiles = {}
local handlers = {}
local synced, granted = 0, {}
local restoreResult, reviveResult = 0, 0
local serverParent = {
	PlayerData = {
		get = function(p)
			return profiles[p]
		end,
		sync = function()
			synced += 1
		end,
	},
	Shop = {
		reply = function(ok, message, data)
			local out = { Ok = ok, Message = message }
			for k, v in data or {} do
				out[k] = v
			end
			return out
		end,
		register = function(name, fn)
			handlers[name] = fn
		end,
	},
	StoreServer = {
		grant = function(p, reward)
			table.insert(granted, reward)
			return {}
		end,
	},
}
local serverEnv = setmetatable({
	game = {
		GetService = function(_, name)
			return { Name = name, Shared = setmetatable({}, { __index = function(_, k) return k end }) }
		end,
	},
	script = { Parent = serverParent },
	require = function(name)
		if type(name) == "table" then
			return name
		end
		return shared(name)
	end,
}, { __index = _G })
local CouponServer = luau.load(fs.readFile(ROOT .. "/src/server/Systems/CouponServer.luau"), {
	debugName = "CouponServer",
	environment = serverEnv,
})()
CouponServer.start()
local use = handlers.UseCoupon
check(use ~= nil, "UseCoupon isn't registered")
local player = { Name = "Ana" }
profiles[player] = { Coupons = { Swings = 1, Revive = 1, XPBoost = 1 } }
-- (Nothing wired in: a restore and a revive do nothing, and are kept.)
local result = use(player, "Swings")
check(not result.Ok and Coupons.count(profiles[player], "Swings") == 1, "A swing coupon spent with nothing to restore")
CouponServer.restoreSwings = function(_, share)
	check(share == SwingRestore.Coupon, "A swing coupon's share")
	return restoreResult
end
CouponServer.reviveKaiju = function()
	return reviveResult
end
result = use(player, "Swings")
check(not result.Ok and string.find(result.Message, "full", 1, true) and Coupons.count(profiles[player], "Swings") == 1, "A full pick spent a coupon")
restoreResult = 300
result = use(player, "Swings")
check(result.Ok and result.Left == 0 and string.find(result.Message, "+300", 1, true), "A swing coupon didn't restore")
result = use(player, "Swings")
check(not result.Ok and string.find(result.Message, "no Swing Restore", 1, true), "A coupon spent from none")
result = use(player, "Revive")
check(not result.Ok and Coupons.count(profiles[player], "Revive") == 1, "A revive coupon spent with none down")
reviveResult = 2
result = use(player, "Revive")
check(result.Ok and Coupons.count(profiles[player], "Revive") == 0 and string.find(result.Message, "2 kaiju", 1, true), "A revive coupon didn't revive")
result = use(player, "XPBoost")
check(result.Ok and #granted == 1 and granted[1].XPBoostMinutes == 30, "Double XP not granted")
check(not use(player, "Gold").Ok and not use({}, "Swings").Ok, "A coupon that isn't one, or no profile")
check(synced >= 3, "Coupons spent without a sync")

print(string.format("PASS: %d reward checks (tournament shares, restores never past full, casual runs, coupons per friend, spending them, the kaiju revive product)", checks))
