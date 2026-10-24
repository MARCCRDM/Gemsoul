-- lune run tests/referrals_cases.luau <repo>
-- Bring a friend (Shared.Referrals, Systems/Referrals): a friend who joins
-- through your invite is counted once, you earn Kindred Edge, a Legendary weapon
-- skin only found here (online now, in another server, or on your next
-- join), self-invites and junk don't count, a failed save is tried again,
-- and it is never sold or dropped.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local Rules = luau.load(fs.readFile(ROOT .. "/src/shared/Referrals.luau"), { debugName = "Referrals" })()

-- Rules -------------------------------------------------------------------------
check(Rules.referrer({ ReferredByPlayerId = 42 }, 7) == 42, "A referral wasn't read")
check(Rules.referrer({ ReferredByPlayerId = 7 }, 7) == nil, "A self-invite counted")
check(Rules.referrer({ ReferredByPlayerId = 0 }, 7) == nil, "No invite counted")
check(Rules.referrer({}, 7) == nil and Rules.referrer(nil, 7) == nil, "Missing join data counted")
check(Rules.referrer({ ReferredByPlayerId = 1.5 }, 7) == nil, "A junk id counted")
local entry, fresh = Rules.record(nil, 100)
check(fresh and entry.Count == 1, "The first friend wasn't counted")
entry, fresh = Rules.record(entry, 100)
check(not fresh and entry.Count == 1, "A rejoining friend counted twice")
entry, fresh = Rules.record(entry, 101)
check(fresh and entry.Count == 2, "A second friend wasn't counted")
check(Rules.record({ Friends = { x = "yes" }, Count = 99 }, 5).Count == 1, "A tampered record was trusted")
check(not Rules.earned(0) and Rules.earned(Rules.Needed), "Earned threshold wrong")

-- The skin: exclusive, never sold or in crates, works on any weapon ------------
local cosmeticsSource = fs.readFile(ROOT .. "/src/shared/Cosmetics.luau")
local orderBlock = string.match(cosmeticsSource, "Cosmetics.Order = (%b{})")
check(orderBlock and not string.find(orderBlock, Rules.Reward, 1, true), "The skin is sold or drops from crates")
local entryAt = string.find(cosmeticsSource, Rules.Reward .. " = {", 1, true)
check(entryAt ~= nil, "The reward isn't a cosmetic")
local skinEntry = string.sub(cosmeticsSource, entryAt, (string.find(cosmeticsSource, "},", entryAt, true)))
check(string.find(skinEntry, 'Kind = "Skin"', 1, true) ~= nil, "The reward isn't a weapon skin")
check(string.find(skinEntry, 'Exclusive = "Invite"', 1, true) ~= nil, "The reward isn't marked exclusive")
check(string.find(skinEntry, "Price", 1, true) == nil, "The skin has a price")
local look = string.match(skinEntry, 'Look = "(%w+)"')
local equipmentSource = fs.readFile(ROOT .. "/src/server/Systems/Equipment.luau")
check(look and string.find(equipmentSource, "SKINS." .. look .. " =", 1, true) ~= nil, "The skin has no look")
-- Equipping takes a skin by name, or as one of each miner's own looks.
local storeSource = fs.readFile(ROOT .. "/src/server/Systems/StoreServer.luau")
local minerKinds = string.match(cosmeticsSource, "function Cosmetics%.isMinerKind%(kind: any%): boolean%s*return ([^\n]+)")
check(
	string.find(storeSource, 'kind ~= "Skin"', 1, true) ~= nil
		or (
			string.find(storeSource, "Cosmetics.isMinerKind(kind)", 1, true) ~= nil
			and minerKinds ~= nil
			and string.find(minerKinds, 'kind == "Skin"', 1, true) ~= nil
		),
	"A skin can't be equipped"
)

-- Server flow, with a fake DataStore and players --------------------------------
local stored = {}
local failSaves = 0 -- the next saves to fail (a DataStore outage)
local dataStore = {
	GetAsync = function(_, key)
		return stored[key]
	end,
	UpdateAsync = function(_, key, fn)
		if failSaves > 0 then
			failSaves -= 1
			error("DataStore request failed")
		end
		stored[key] = fn(stored[key])
	end,
}
-- Cross-server messages: what this server sent, and its subscription.
local published = {}
local subscribed = nil
local messaging = {
	PublishAsync = function(_, topic, data)
		table.insert(published, { Topic = topic, Data = data })
	end,
	SubscribeAsync = function(_, topic, fn)
		subscribed = { Topic = topic, Fn = fn }
	end,
}
local online = {}
local added = {}
local profiles = {}
local syncs = 0
local function makePlayer(userId, referredBy)
	local player = {
		UserId = userId,
		Parent = "Players",
		GetJoinData = function()
			return { ReferredByPlayerId = referredBy }
		end,
	}
	profiles[player] = { Cosmetics = { Owned = {} } }
	return player
end
local handlers = {}
local notes = {}
local Coupons = luau.load(fs.readFile(ROOT .. "/src/shared/Coupons.luau"), {
	debugName = "Coupons",
	environment = setmetatable({ Color3 = roblox.Color3 }, { __index = _G }),
})()
local stubs = {
	Config = { DataStoreName = "Test" },
	Coupons = Coupons,
	Remotes = {
		Notify = {
			FireClient = function(_, player, text)
				table.insert(notes, { Player = player, Text = text })
			end,
		},
	},
	Cosmetics = {
		get = function(id)
			local kinds = {
				SkinKindred = "Skin",
				PickTwinStar = "Pick",
				VisorStarlink = "Visor",
				SkinCrusader = "Skin",
				SuitCrusader = "Suit",
				ShieldAegis = "Shield",
			}
			return if kinds[id] then { Id = id, Kind = kinds[id], Name = id } else nil
		end,
	},
	Referrals = Rules,
	PlayerData = {
		get = function(player)
			return profiles[player]
		end,
		sync = function()
			syncs += 1
		end,
		setCosmetic = function(player, kind, id)
			profiles[player].Cosmetics[kind] = id
		end,
	},
	Shop = {
		register = function(name, fn)
			handlers[name] = fn
		end,
		reply = function(ok, message, extra)
			local r = extra or {}
			r.Ok, r.Message = ok, message
			return r
		end,
	},
}
local Players = {
	GetPlayers = function()
		return {}
	end,
	GetPlayerByUserId = function(_, id)
		return online[id]
	end,
	PlayerAdded = {
		Connect = function(_, fn)
			table.insert(added, fn)
		end,
	},
}
local env = setmetatable({
	game = {
		GetService = function(_, name)
			if name == "DataStoreService" then
				return {
					GetDataStore = function()
						return dataStore
					end,
				}
			elseif name == "Players" then
				return Players
			elseif name == "MessagingService" then
				return messaging
			end
			return { Shared = setmetatable({}, {
				__index = function(_, k)
					return k
				end,
			}) }
		end,
	},
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return stubs[name]
	end,
	task = {
		wait = function()
			return 0.5
		end,
		spawn = function(fn, ...)
			fn(...)
		end,
	},
}, { __index = _G })
local Referrals = luau.load(
	fs.readFile(ROOT .. "/src/server/Systems/Referrals.luau"),
	{ debugName = "Referrals.server", environment = env }
)()
Referrals.start()
local function join(player)
	online[player.UserId] = player
	for _, fn in added do
		fn(player)
	end
end

-- The inviter (1) is away: their friend (2) joins through the invite.
local inviter = makePlayer(1, 0)
local friend = makePlayer(2, 1)
join(friend)
check(stored["1"] and stored["1"].Count == 1, "The friend's join wasn't recorded")
check(not profiles[friend].Cosmetics.Owned[Rules.Reward], "The invited friend got the inviter's reward")
-- The inviter comes back: the reward is theirs.
join(inviter)
check(
	profiles[inviter].Cosmetics.Owned[Rules.Reward] == true and profiles[inviter].Cosmetics.Skin == Rules.Reward,
	"The inviter didn't get (and wear) the skin on joining"
)
local state = handlers.ReferralState(inviter)
check(state.Ok and state.Claimed and state.Count == 1, "CHECK CLAIM didn't confirm the reward")
-- Rejoining doesn't count twice.
join(friend)
check(stored["1"].Count == 1, "A rejoin counted twice")
-- An online inviter gets it the moment their friend joins.
local host = makePlayer(10, 0)
join(host)
check(not handlers.ReferralState(host).Claimed, "Claimed with no friend joined")
join(makePlayer(11, 10))
check(profiles[host].Cosmetics.Owned[Rules.Reward] == true, "An online inviter wasn't rewarded at once")
-- Inviting yourself doesn't count.
local cheat = makePlayer(20, 20)
join(cheat)
check(stored["20"] == nil and not profiles[cheat].Cosmetics.Owned[Rules.Reward], "A self-invite counted")

-- The first reward is the special one.
check(Rules.Reward == "SkinKindred" and Rules.Needed == 1, "One friend doesn't earn Kindred Edge")

-- The ladder: every tier reached, each worn; the next ones wait.
check(#Rules.rewardsFor(0) == 0 and #Rules.rewardsFor(1) == 1 and #Rules.rewardsFor(4) == 4, "Tier rewards miscounted")
check(Rules.rewardsFor(2)[2] == "PickTwinStar", "Two friends don't earn the Twin Star pickaxe")
check(Rules.rewardsFor(4)[4] == "SkinCrusader", "Four friends don't earn Crusader Gold")
check(#Rules.rewardsFor(10) == #Rules.Tiers and Rules.nextTier(10) == nil, "The top tier isn't the last")
check(Rules.nextTier(3).Friends == 4 and Rules.nextTier(4).Friends == 5, "The next tiers after 3 and 4 friends are wrong")
for i = 2, #Rules.Tiers do
	check(Rules.Tiers[i].Friends > Rules.Tiers[i - 1].Friends, "The ladder isn't in order")
end
local recruiter = makePlayer(30, 0)
join(recruiter)
for friendId = 31, 33 do
	join(makePlayer(friendId, 30))
end
local owned = profiles[recruiter].Cosmetics
check(owned.Owned.SkinKindred and owned.Owned.PickTwinStar and owned.Owned.VisorStarlink, "Three friends didn't unlock the first three tiers")
check(
	not owned.Owned.SkinCrusader and not owned.Owned.SuitCrusader and not owned.Owned.ShieldAegis,
	"Three friends unlocked a higher tier"
)
check(owned.Skin == "SkinKindred" and owned.Pick == "PickTwinStar" and owned.Visor == "VisorStarlink", "The tier rewards weren't worn")
join(makePlayer(34, 30))
check(owned.Owned.SkinCrusader and owned.Skin == "SkinCrusader", "The fourth friend didn't unlock (and put on) Crusader Gold")
check(owned.Owned.SkinKindred, "Kindred Edge was lost on reaching the next tier")
-- Reward coupons (Shared.Coupons): one of each per friend, once.
local held = profiles[recruiter]
check(
	Coupons.count(held, "Swings") == 4 and Coupons.count(held, "Revive") == 4 and Coupons.count(held, "XPBoost") == 4,
	"Four friends didn't give four of each coupon"
)
check(held.Referrals.CouponsPaid == 4, "The friends paid for weren't kept")
handlers.ReferralState(recruiter)
check(Coupons.count(held, "Swings") == 4, "A check paid the same friends' coupons again")
local told = false
for _, note in notes do
	told = told or (note.Player == recruiter and string.find(note.Text, "coupons", 1, true) ~= nil)
end
check(told, "The inviter wasn't told about the coupons")
for friendId = 301, 306 do join(makePlayer(friendId, 30)) end
check(owned.Owned.ShieldAegis and owned.Shield == "ShieldAegis", "Ten friends must unlock and wear the shield")
check(owned.Visor == "VisorStarlink" and owned.Skin == "SkinCrusader", "Shield reward replaced another cosmetic slot")
check(not owned.Owned.BackStandard and not owned.Owned.TitleLegend, "Retired invitation rewards were still granted")

-- A failed save is tried again: the friend still counts.
local patient = makePlayer(40, 0)
join(patient)
failSaves = 2
join(makePlayer(41, 40))
check(failSaves == 0 and stored["40"] and stored["40"].Count == 1, "A friend's join was lost to a failed save")
check(profiles[patient].Cosmetics.Owned[Rules.Reward] == true, "The retried join didn't reward the inviter")

-- The inviter is in another server: this one tells it.
local elsewhere = makePlayer(50, 0) -- (never joins this server)
join(makePlayer(51, 50))
local sent = published[#published]
check(
	sent and sent.Topic == subscribed.Topic and sent.Data.Referrer == 50 and sent.Data.Count == 1,
	"A friend's join wasn't announced to the inviter's server"
)
check(not profiles[elsewhere].Cosmetics.Owned[Rules.Reward], "An absent inviter was rewarded here")
-- And in the inviter's server, the message rewards them at once, even
-- before the store's copy there catches up.
local away = makePlayer(60, 0)
join(away)
check(not profiles[away].Cosmetics.Owned[Rules.Reward], "Rewarded before any friend joined")
check(subscribed ~= nil, "This server doesn't listen for friends joining elsewhere")
subscribed.Fn({ Data = { Referrer = 60, Count = 1 } })
check(
	profiles[away].Cosmetics.Owned[Rules.Reward] == true and profiles[away].Cosmetics.Skin == Rules.Reward,
	"A friend joining in another server didn't reward the inviter here"
)
subscribed.Fn({ Data = { Referrer = 999, Count = 3 } })
subscribed.Fn({ Data = "junk" })
subscribed.Fn(nil)
check(true, "Junk messages broke the listener")
-- The check reports success apart from whether it's claimed.
local fresh = makePlayer(70, 0)
join(fresh)
local reported = handlers.ReferralState(fresh)
check(reported.Ok and not reported.Claimed and reported.Count == 0, "A check with no friends yet read as a failure")

print(
	"PASS: "
		.. checks
		.. " bring-a-friend checks (referrer, once per friend, offline, online and other-server inviters, retried saves, self-invites, Kindred Edge, reward tiers)"
)
