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
local introSteps = {} -- (the Intro Rounds funnel's steps, as sent)
local socketed = 0
local profile
local attributes = {}
local player = {
	Name = "Newbie", UserId = 1, Parent = true,
	SetAttribute = function(_, k, v) attributes[k] = v end,
	GetAttribute = function(_, k) return attributes[k] end,
}
local gemIds = 0
local warmed = {}
local stubs = {
	Analytics = {
		event = function(_, name, ...) table.insert(events, { name, ... }) end,
		introStep = function(_, step) table.insert(introSteps, step) end,
	},
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
	-- (the reel's pictures: IntroRoundsServer.warm)
	Equipment = { groupPreviews = function(_, group, items) table.insert(warmed, { group, items }) return true end },
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
	task = { spawn = function(f, ...) f(...) end, delay = function() end, wait = function() end },
	workspace = { FindFirstChild = function() return nil end }, -- (no rival up: Server._rivalUp)
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
	-- (the card's roll: the strip, from this slot's pools, stopping on the piece)
	local strip, land = event[2].Reel, event[2].ReelLand
	check(type(strip) == "table" and #strip == Server.ReelLength and land == Server.ReelLand, "No roll for round " .. round)
	check(strip[land].Name == piece.Name and strip[land].Rarity == piece.Rarity, "The roll doesn't stop on the piece won")
	local names = {}
	for _, rarity in { "Uncommon", "Rare" } do
		for _, gear in Server._pool(slot, rarity) do
			names[gear.Name] = rarity
		end
	end
	for i, entry in strip do
		check(i == land or names[entry.Name] == entry.Rarity, "The roll shows a piece this round can't give: " .. tostring(entry.Name))
	end
	-- (each tile names its piece, so it's drawn in 3D; its picture was asked for)
	check(strip[land].Id == piece.Id, "The roll's piece has no id to draw")
	local asked = warmed[#warmed]
	check(asked ~= nil and asked[1] == "R", "The reel's pictures were never asked for")
	for _, entry in strip do
		check(entry.Id ~= nil and asked[2][entry.Id] ~= nil and asked[2][entry.Id].Slot == slot, "A tile's picture isn't built: " .. tostring(entry.Name))
	end
	check(profile.IntroRounds.Losses == 0, "A win didn't reset the losses")
	if round == IntroRounds.GemAfter then
		check(event[2].Gem ~= nil, "No gem at round " .. round)
		-- (auto-equipped: the round's gem goes straight into a socket)
		check(socketed >= 1 and #profile.Gems == 0, "The round's gem wasn't auto-socketed")
	end
	if round < IntroRounds.Count then
		check(attributes.IntroRounds == true and coins == 0, "The rounds ended early")
		-- (all six before the lobby: no leaving, and no finale yet)
		check(Server.left(player) == IntroRounds.Count - round and attributes.IntroRoundsLeft == IntroRounds.Count - round, "The rounds left aren't on them")
		check(attributes.IntroFinale == nil and profile.IntroFinale == nil, "The finale came before the set's done")
	end
end
-- The set done: free to leave, and the first dungeon owed before the lobby's intro.
check(Server.left(player) == 0 and attributes.IntroRoundsLeft == nil, "Still held in the rounds after the set")
check(profile.IntroFinale == "Dungeon" and attributes.IntroFinale == "Dungeon", "The first dungeon isn't owed after the set")
check(Server.finale(player, "Done").Ok == false and profile.IntroFinale == "Dungeon", "The lobby's intro finished before the first dungeon")
-- A Rift boss beaten: the lobby's intro (the mines, the minions, the kaiju) is next.
check(Server.dungeonCleared(player) and profile.IntroFinale == "Mines" and attributes.IntroFinale == "Mines", "Clearing the first dungeon didn't open the lobby's intro")
check(attributes.IntroDungeonCleared == true, "The lobby's intro would ask about a dungeon already done")
check(not Server.dungeonCleared(player) and profile.IntroFinale == "Mines", "A second boss beaten moved the intro on again")
check(Server.finale(player, "Nonsense").Ok == false, "An unknown finale step went through")
-- (the step it's on, for the DEV spectator; only the finale's own steps)
check(Server.finale(player, "Step", "Gems").Ok and attributes.IntroFinaleStep == "Gems", "The finale's step isn't shown")
Server.finale(player, "Step", "Hax")
check(attributes.IntroFinaleStep == nil, "Any word went up as the finale's step")
-- The first dungeon's window: their answer goes to Analytics (anything but Go is Later).
local function lastEvent(name)
	for i = #events, 1, -1 do
		if events[i][1] == name then
			return events[i]
		end
	end
	return nil
end
check(Server.finale(player, "Invite", "Go").Ok and lastEvent("IntroDungeonInvite")[2] == "Go", "ENTER DUNGEON wasn't sent to Analytics")
check(Server.finale(player, "Invite", "Hax").Ok and lastEvent("IntroDungeonInvite")[2] == "Later", "Any answer went to Analytics as itself")
check(profile.IntroFinale == "Mines", "Answering the dungeon's window ended the finale")
check(Server.finale(player, "Done").Ok and profile.IntroFinale == "Done" and attributes.IntroFinale == nil, "The finale didn't finish")
check(Server.finale(player, "Done").Ok == false, "The finale finished twice")
-- (the dungeon detour's off for everyone, the Owners too)
check(not Server.dungeonPath(player), "The intro still goes by the dungeon")
check(rares >= 1, "No Rare in the whole set")
check(coins == IntroRounds.SetCoins and fired[#fired][2].View.Done, "The set's coins weren't paid")
check(attributes.IntroRounds == nil and not Server.eligible(player), "Still on the rounds after the set")
check(Server.won(player) == nil, "A seventh piece")
check(#events >= IntroRounds.Count, "Rounds not sent to Analytics")
-- The Intro Rounds funnel: every round's start and win, once each, in order.
check(#introSteps == IntroRounds.Count * 2, "The intro funnel sent " .. #introSteps .. " steps, not 12")
for i, step in introSteps do
	check(step == i, "The intro funnel's step " .. i .. " came as " .. tostring(step))
end
local before = #introSteps
Server.funnel(player, profile.IntroRounds, 3, true)
Server.funnel(player, profile.IntroRounds, 3, false)
check(#introSteps == before, "An intro funnel step was sent twice")
-- (a round started: its own step, before its win)
local fresh = { Won = 0, Losses = 0, Pieces = {} }
local mark = #introSteps
Server.funnel(player, fresh, 1, false)
Server.funnel(player, fresh, 1, true)
Server.funnel(player, fresh, 2, false)
check(introSteps[mark + 1] == 1 and introSteps[mark + 2] == 2 and introSteps[mark + 3] == 3 and #introSteps == mark + 3, "Start, win, next start: not 1, 2, 3")

-- The sword's, chest's and shield's stones (Q, E, R) stay through the intro's
-- best build: a better stone in the pouch doesn't take their place.
do
	profile = newProfile({})
	local weak = { Id = "weak", Element = "Frost", Tier = "Common", Size = 1, Clarity = 1, Cut = 1 }
	local strong = { Id = "strong", Element = "Fire", Tier = "Rare", Size = 9, Clarity = 9, Cut = 9 }
	profile.Character.WeaponGem = weak
	profile.Gems = { strong }
	Server.won(player)
	check(profile.Character.WeaponGem and profile.Character.WeaponGem.Id == "weak", "The intro's best build swapped the sword's stone (its Q)")
	check(#profile.Gems == 1 and profile.Gems[1].Id == "strong", "The better stone left the pouch for the sword")
end

-- The dungeon path (Config.Features.IntroDungeon; the Owners always): two
-- 1v1s, the second's card says the dungeon's next, then the dungeon's
-- first room pays a piece and its boss the rest, a card each.
do
	local Config = shared("Config")
	profile = newProfile({})
	check(not Server.dungeonPath(player), "On the dungeon path with its switch off")
	Config.Features.IntroDungeon = true
	check(Server.dungeonPath(player) and Server.stage(player) == "Duel", "The dungeon path doesn't start with 1v1s")
	fired = {}
	Server.won(player)
	check(fired[#fired][2].Next == nil, "The dungeon's next after one 1v1")
	Server.won(player)
	local second = fired[#fired][2]
	check(second.Next == "Dungeon" and second.Where == nil, "The second 1v1's card doesn't say the dungeon's next")
	check(Server.stage(player) == "Dungeon", "Not on to the dungeon after two 1v1s")
	check(Server.dungeonWon(player, "Room") == 1 and profile.IntroRounds.Won == 3, "The first room didn't pay a piece")
	local roomCard = fired[#fired][2]
	check(roomCard.Where == "Dungeon" and roomCard.More == 0 and roomCard.Round == 3 and not roomCard.View.Done, "The room's card")
	check(Server.dungeonWon(player, "Room") == 0, "The first room paid twice")
	local before = #fired
	check(Server.dungeonWon(player, "Boss") == 3 and profile.IntroRounds.Won == 6, "The boss didn't pay the rest")
	check(#fired == before + 3, "Not a card a piece")
	check(fired[before + 1][2].More == 2 and fired[before + 2][2].More == 1 and fired[before + 3][2].More == 0, "The cards' count of more to come")
	check(fired[before + 3][2].View.Done and fired[before + 3][2].Coins == IntroRounds.SetCoins, "The last card isn't the set's")
	check(Server.stage(player) == "Done" and Server.dungeonWon(player, "Boss") == 0, "Paid past the set")
	Config.Features.IntroDungeon = nil
end

-- Never stuck in the intro's Arena (Server.unstick, the watch's look at a player).
do
	local nexts, leaves = 0, 0
	local realNext, realLeave = Server._next, Server._leave
	Server._next = function() nexts += 1 end
	Server._leave = function() leaves += 1 end
	profile = newProfile({})
	attributes.CombatSession = "Training"
	check(Server.left(player) == IntroRounds.Count, "A new set has rounds left")
	check(Server.unstick(player, 100) == nil and Server.unstick(player, 100 + Server.StuckAfter - 1) == nil, "Moved on too soon")
	check(Server.unstick(player, 100 + Server.StuckAfter + 1) == "Next" and nexts == 1, "Left in the Arena with no rival and rounds to go")
	-- The set done but still in there: out to the finale.
	profile.IntroRounds.Won = IntroRounds.Count
	profile.IntroFinale = "Mines"
	check(Server.unstick(player, 500) == nil, "Taken out the moment the set was done (the card's CONTINUE first)")
	check(Server.unstick(player, 500 + Server.DoneOutAfter + 1) == "Out" and leaves == 1, "Left in the Arena after the set")
	-- Practice after the intro: never moved.
	profile.IntroFinale = "Done"
	check(Server.unstick(player, 1000) == nil and Server.unstick(player, 2000) == nil, "A veteran's practice was cut short")
	attributes.CombatSession = nil
	check(Server.unstick(player, 3000) == nil, "Moved someone not in the Arena")
	Server._next, Server._leave = realNext, realLeave
end

-- The card after the first win: one way on, HUNT BOUNTY (the first
-- dungeon). Not the lobby: that opens once the dungeon's cleared. The rest
-- of the set waits (PLAY, or the lobby's recommendation, takes it up again).
do
	profile = newProfile({})
	check(not Server.choose(player, "Boss").Ok, "Stepped out before winning a fight")
	Server.won(player)
	check(attributes.IntroRoundsLeft == IntroRounds.Count - 1 and Server.held(player), "Not held in the rounds after the first win")
	check(not Server.choose(player, "Hax").Ok, "A way out that isn't one")
	check(not Server.choose(player, "Outpost").Ok and Server.held(player), "Went to the lobby before the first dungeon")
	local out = Server.choose(player, "Boss")
	check(out.Ok and out.Choice == "Boss", "HUNT BOUNTY didn't take them out")
	check(profile.IntroRounds.Paused == true and not Server.held(player) and attributes.IntroRoundsLeft == nil, "Still held after stepping out")
	check(profile.IntroFinale == "Dungeon" and attributes.IntroFinale == "Dungeon", "The first dungeon isn't owed")
	check(Server.owesDungeon(player), "The Rift wouldn't pay the first dungeon's purse")
	check(Server.left(player) == IntroRounds.Count - 1, "Stepping out lost them their rounds")
	check(Server.dungeonCleared(player) and profile.IntroFinale == "Mines", "Clearing it didn't open the lobby's intro")
	check(not Server.owesDungeon(player), "The first dungeon's purse paid twice")
	-- (the rest of the set, from the lobby: held in it again)
	pcall(Server._next, player)
	check(profile.IntroRounds.Paused == nil and Server.held(player) and attributes.IntroRoundsLeft == IntroRounds.Count - 1, "Back to the rounds but not held in them")
	-- After the dungeon: a win's card is the next round (no Hunt), and an old
	-- card's HUNT BOUNTY puts on their next round, never out of the rounds.
	local state = profile.IntroRounds
	check(not Server.huntNext(profile, state), "HUNT BOUNTY again after the first dungeon (Mines)")
	profile.IntroFinale = "Done"
	check(not Server.huntNext(profile, state), "HUNT BOUNTY again after the first dungeon (Done)")
	local realNext = Server._next
	local pausedBefore, nexted = state.Paused, 0
	Server._next = function()
		nexted += 1
		return { Ok = true, Message = "Round" }
	end
	local again = Server.choose(player, "Boss")
	check(again.Ok and again.Choice ~= "Boss" and nexted == 1, "An old HUNT BOUNTY didn't put on their next round after the dungeon")
	check(state.Paused == pausedBefore and Server.held(player), "An old HUNT BOUNTY took them out of the rounds after the dungeon")
	Server._next = realNext
	-- Not cleared yet: HUNT BOUNTY (not begun, or owed), and never on the set's last.
	check(Server.huntNext({ IntroFinale = nil }, { Won = 1 }) and Server.huntNext({ IntroFinale = "Dungeon" }, { Won = 3 }), "No HUNT BOUNTY while the first dungeon's owed")
	check(not Server.huntNext({ IntroFinale = nil }, { Won = 0 }) and not Server.huntNext({ IntroFinale = nil }, { Won = IntroRounds.Count }), "HUNT BOUNTY before a win, or on the set's last")
	check(not Server.huntNext({ IntroFinale = "Dungeon", IntroDungeonCleared = true }, { Won = 2 }), "HUNT BOUNTY with the dungeon cleared")
	-- (an old save that finished the lobby's intro before the dungeon came first)
	check(not Server.huntNext({ IntroFinale = "Done" }, { Won = 2 }), "HUNT BOUNTY for an older save")
end
print(string.format("PASS: %d intro rounds server checks", checks))
