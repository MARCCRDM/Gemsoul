-- lune run tests/referrals_cases.luau <repo>
-- Bring a friend (Shared.Referrals, Systems/Referrals): a friend who joins
-- through your invite is counted once, you earn the Crusader's Standard weapon (online
-- now, or on your next join), self-invites and junk don't count, and it
-- never drops.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
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

-- The weapon: exclusive, never drops, never in crates ---------------------------
local classesSource = fs.readFile(ROOT .. "/src/shared/Classes.luau")
local entryAt = string.find(classesSource, 'Id = "' .. Rules.Reward .. '"', 1, true)
check(entryAt ~= nil, "The reward isn't a weapon in Classes")
local weaponEntry = string.sub(classesSource, entryAt, (string.find(classesSource, "})", entryAt, true)))
check(string.find(weaponEntry, 'Exclusive = "Referral"', 1, true) ~= nil, "The reward isn't marked exclusive")
check(string.find(weaponEntry, 'WeaponType = "Sword"', 1, true) ~= nil, "The reward would be turned into a pistol")
check(string.find(weaponEntry, "StartPool", 1, true) == nil, "The reward can be drawn as a starter or a drop")
check(
	string.find(fs.readFile(ROOT .. "/src/shared/ExpandedItemTraits.luau"), Rules.Reward, 1, true) == nil,
	"The reward is in the mine-drop catalog"
)
check(
	string.find(fs.readFile(ROOT .. "/src/server/Systems/Equipment.luau"), "WEAPONS.Standard =", 1, true) ~= nil,
	"The reward has no 3D model"
)

-- Server flow, with a fake DataStore and players --------------------------------
local stored = {}
local dataStore = {
	GetAsync = function(_, key)
		return stored[key]
	end,
	UpdateAsync = function(_, key, fn)
		stored[key] = fn(stored[key])
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
	profiles[player] = { Owned = { Weapons = {} } }
	return player
end
local handlers = {}
local stubs = {
	Classes = {
		weapon = function(class, id)
			return if class == "Warrior" and id == Rules.Reward
				then { Id = Rules.Reward, Name = "Crusader's Standard" }
				else nil
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
		setGearQuality = function(player, kind, id, quality)
			profiles[player].Owned[kind][id] = quality
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
check(not profiles[friend].Owned.Weapons[Rules.Reward], "The invited friend got the inviter's reward")
-- The inviter comes back: the reward is theirs.
join(inviter)
check(profiles[inviter].Owned.Weapons[Rules.Reward] == 1, "The inviter didn't get the reward on joining")
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
check(profiles[host].Owned.Weapons[Rules.Reward] == 1, "An online inviter wasn't rewarded at once")
-- Inviting yourself doesn't count.
local cheat = makePlayer(20, 20)
join(cheat)
check(stored["20"] == nil and not profiles[cheat].Owned.Weapons[Rules.Reward], "A self-invite counted")

print(
	"PASS: "
		.. checks
		.. " bring-a-friend checks (referrer, once per friend, offline and online inviters, self-invites, exclusive weapon)"
)
