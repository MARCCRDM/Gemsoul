-- lune run tests/intro_rounds_server.luau <repo>
-- The intro rounds' server (Server.IntroRoundsServer) against stand-in
-- services: six wins give six pieces, one per slot in order, equipped; the
-- sword round only swords; a gem at round GemAfter; the set's coins at the
-- end; losses; and nothing for accounts that aren't new.
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
local cache = {}
local baseEnv = {
	Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, UDim2 = roblox.UDim2,
	-- (lune has no Random: a stand-in on math.random)
	Random = {
		new = function(seed)
			if seed then math.randomseed(seed) end
			return {
				NextInteger = function(_, a, b) return math.random(a, b) end,
				NextNumber = function(_, a, b) a, b = a or 0, b or 1; return a + math.random() * (b - a) end,
			}
		end,
	},
}
local function shared(name)
	if cache[name] then return cache[name] end
	local env = setmetatable({
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		game = { GetService = function() return { Shared = setmetatable({}, { __index = function(_, k) return k end }) } end },
		require = function(m) return shared(m) end,
	}, { __index = _G })
	for k, v in baseEnv do env[k] = v end
	cache[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
	return cache[name]
end
local IntroRounds = shared("IntroRounds")
local Slots = shared("EquipmentSlots")

-- Stand-ins.
local fired, equipped, coins, events = {}, {}, 0, {}
local socketed = 0
local profile
local attributes = {}
local player = {
	Name = "Newbie", UserId = 1,
	SetAttribute = function(_, k, v) attributes[k] = v end,
	GetAttribute = function(_, k) return attributes[k] end,
}
local gemIds = 0
local stubs = {
	Analytics = { event = function(_, name, ...) table.insert(events, { name, ... }) end },
	PlayerData = {
		get = function() return profile end,
		sync = function() end,
		equipGear = function(_, kind, key)
			table.insert(equipped, { Kind = kind, Key = key })
			profile.Character[Slots.ByKind[kind]] = key
			return true
		end,
		addCoins = function(_, n) coins += n end,
		socketGem = function(_, gemId, slot)
			for i, gem in profile.Gems do
				if gem.Id == gemId then
					table.remove(profile.Gems, i)
					profile.Character[slot .. "Gem"] = gem
					socketed += 1
					return gem
				end
			end
			return nil
		end,
		newGemId = function() gemIds += 1 return "g" .. gemIds end,
	},
	Remotes = {
		Social = { FireClient = function(_, _, kind, event) table.insert(fired, { kind, event }) end },
		Notify = { FireClient = function() end },
	},
	Shop = { reply = function(ok, message, extra) local r = extra or {}; r.Ok, r.Message = ok, message; return r end, register = function() end },
	Forge = { counted = function() end },
	GemGenerator = { generate = function(_, _, spec) return { Id = spec.Id, Element = "Fire", Tier = spec.Rarity, Size = 5, Clarity = 5, Cut = 5 } end },
}
local names = setmetatable({}, { __index = function(_, k) return k end })
local env = setmetatable({
	game = {
		GetService = function(_, service)
			if service == "ReplicatedStorage" then return { Shared = names } end
			return { PlayerRemoving = { Connect = function() end } }
		end,
	},
	script = { Parent = names },
	require = function(name) return stubs[name] or shared(name) end,
	warn = function(...) print("warn:", ...) end,
}, { __index = _G })
for k, v in baseEnv do env[k] = v end
local Server = luau.load(fs.readFile(ROOT .. "/src/server/Systems/IntroRoundsServer.luau"), { debugName = "IntroRoundsServer", environment = env })()

local function newProfile(funnel)
	return {
		Funnel = funnel,
		Owned = { Weapons = {}, Shields = {}, Helmets = {}, Armors = {}, Gloves = {}, Boots = {} },
		Character = { Class = "Warrior", GearRolls = {}, ItemGems = {} },
		Gems = {},
		Coins = 0,
	}
end

-- Every round's pool has gear; the sword round's only swords.
for _, slot in IntroRounds.Order do
	for _, rarity in { "Uncommon", "Rare" } do
		local pool = Server._pool(slot, rarity)
		check(#pool > 0, string.format("No %s %s to give", rarity, slot))
		for _, gear in pool do
			if slot == "Weapon" then
				check(gear.WeaponType == "Sword", "A non-sword in the sword round: " .. tostring(gear.Id))
			end
		end
	end
end

-- An old account: nothing.
profile = newProfile(nil)
check(Server.won(player) == nil and #fired == 0 and not Server.eligible(player), "An old account got an intro piece")
check(Server.lost(player) == false, "An old account lost a round")

-- A new one: six wins, six pieces, in order, each equipped.
profile = newProfile({})
check(Server.eligible(player), "A new account isn't on its intro rounds")
check(Server.lost(player) and profile.IntroRounds.Losses == 1, "A loss wasn't counted")
check(fired[#fired][2].Phase == "Lost" and attributes.IntroRounds == true, "No Lost card")
local rares = 0
for round = 1, IntroRounds.Count do
	local piece = Server.won(player)
	local slot = IntroRounds.Order[round]
	check(piece ~= nil and piece.Slot == slot, "Round " .. round .. " didn't pay its " .. slot)
	check(piece.Rarity == "Uncommon" or piece.Rarity == "Rare", "A piece outside Uncommon/Rare")
	if piece.Rarity == "Rare" then rares += 1 end
	local kind = Slots.Definitions[slot].Kind
	check(profile.Owned[kind][piece.Id] ~= nil, "The piece isn't owned")
	check(equipped[#equipped].Kind == kind and profile.Character[slot] == piece.Id, "The piece isn't worn")
	check(profile.Character.GearRolls[kind][piece.Id] ~= nil, "The piece has no roll")
	local event = fired[#fired]
	check(event[1] == "IntroRound" and event[2].Phase == "Won" and event[2].Round == round, "No Won card for round " .. round)
	check(profile.IntroRounds.Losses == 0, "A win didn't reset the losses")
	if round == IntroRounds.GemAfter then
		check(event[2].Gem ~= nil, "No gem at round " .. round)
		-- (auto-equipped: the round's gem goes straight into a socket)
		check(socketed >= 1 and #profile.Gems == 0, "The round's gem wasn't auto-socketed")
	end
	if round < IntroRounds.Count then
		check(attributes.IntroRounds == true and coins == 0, "The rounds ended early")
	end
end
check(rares >= 1, "No Rare in the whole set")
check(coins == IntroRounds.SetCoins and fired[#fired][2].View.Done, "The set's coins weren't paid")
check(attributes.IntroRounds == nil and not Server.eligible(player), "Still on the rounds after the set")
check(Server.won(player) == nil, "A seventh piece")
check(#events >= IntroRounds.Count, "Rounds not sent to Analytics")

print(string.format("PASS: %d intro rounds server checks", checks))
