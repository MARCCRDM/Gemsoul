-- lune run tests/journey_cases.luau <repo>
-- A new player's first session as a journey (Server.Journey): it begins when
-- a new account joins, each node once a session (names Roblox accepts), dev
-- accounts left out, and leaving is its last node, with where they were.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."
local checks = 0
local function check(v, m)
	checks += 1
	if not v then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(m) .. "\n")
		process.exit(1)
	end
end
local removing = {}
local services = {
	AnalyticsService = {},
	HttpService = { GenerateGUID = function() return "guid-1" end },
	Players = { PlayerRemoving = { Connect = function(_, fn) table.insert(removing, fn) end } },
}
local Journey = luau.load(fs.readFile(ROOT .. "/src/server/Systems/Journey.luau"), {
	debugName = "Journey",
	environment = setmetatable({
		game = { GetService = function(_, n) return services[n] end },
		Enum = roblox.Enum,
	}, { __index = _G }),
})()
local sent = {}
Journey.log = function(player, node, session, fields)
	table.insert(sent, { player = player, node = node, session = session, fields = fields })
end
local a = { UserId = 1, Name = "A" }
local b = { UserId = 2, Name = "B" }

-- Not on it (not a new account this visit): nothing.
check(not Journey.reach(a, "Lobby") and #sent == 0, "A node logged for someone not on the journey")
-- A new account joins: Joined, then each node once.
Journey.start(a)
check(Journey.active(a) and #sent == 1 and sent[1].node == "Joined" and sent[1].session == "guid-1", "The journey didn't begin with Joined")
check(Journey.reach(a, "Round 1 won") and not Journey.reach(a, "Round 1 won"), "A node logged twice in a session")
check(#sent == 2, "Wrong count after a repeat")
-- Names Roblox accepts: no commas, quotes or newlines, no leading __.
check(Journey.clean('Bad, "name"\n') == "Bad name", "A comma, quote or newline kept: " .. tostring(Journey.clean('Bad, "name"\n')))
check(Journey.clean("__secret") == "secret" and Journey.clean("   ") == nil and Journey.clean(nil) == nil, "A reserved or empty name let through")
-- Leaving: the last node, with where they were and how long in; then off.
Journey.listen()
check(#removing == 1, "Leaving isn't listened for")
removing[1](a)
local last = sent[#sent]
check(last.node == "Left the game" and last.fields and last.fields.CustomField01 == "Round 1 won", "Leaving didn't say where they were")
check(last.fields.CustomField02 == "under 2 min", "Leaving didn't say how long they'd played")
check(not Journey.active(a) and not Journey.reach(a, "Lobby"), "Still on the journey after leaving")
-- A dev account: on it, nothing sent.
Journey.excluded = function(p) return p == b end
local before = #sent
Journey.start(b)
check(Journey.active(b) and Journey.reach(b, "Lobby") and #sent == before, "A dev account's journey was sent")
removing[1](b)
check(#sent == before, "A dev account's leaving was sent")
-- A cap on a session's nodes (the event budget).
Journey.excluded = function() return false end
local c = { UserId = 3 }
Journey.start(c)
for i = 1, Journey.MaxNodes + 10 do
	Journey.reach(c, "Node " .. i)
end
local count = 0
for _, row in sent do
	if row.player == c then
		count += 1
	end
end
check(count == Journey.MaxNodes, "A session's nodes weren't capped: " .. count)

-- Wired: new accounts begin it (Funnel's Joined), the intro's places reach it.
local function has(path, text)
	return fs.readFile(ROOT .. path):find(text, 1, true) ~= nil
end
check(has("/src/server/Systems/Funnel.luau", "Journey.start(player)"), "A new account doesn't begin the journey")
check(has("/src/server/Main.server.luau", "Systems.Journey).listen()"), "Leaving isn't listened for in the game")
check(has("/src/server/Systems/DevAccounts.luau", "require(script.Parent.Journey).excluded = DevAccounts.excluded"), "Dev accounts aren't left out of the journey")
for _, spot in {
	{ "/src/server/Systems/IntroRoundsServer.luau", "Round %d won" },
	{ "/src/server/Systems/IntroRoundsServer.luau", "Round %d lost" },
	{ "/src/server/Systems/IntroRoundsServer.luau", "Chose HUNT BOUNTY" },
	{ "/src/server/Systems/IntroRoundsServer.luau", "Kept fighting after round %d" },
	{ "/src/server/Systems/IntroRoundsServer.luau", "Cleared the first dungeon" },
	{ "/src/server/Systems/IntroRoundsServer.luau", "Lobby intro " },
	{ "/src/server/Systems/RiftServer.luau", "Entered the first dungeon" },
	{ "/src/server/Systems/RiftServer.luau", "Back from a dungeon" },
	{ "/src/server/Systems/KaijuServer.luau", "Starter kaiju roll" },
} do
	check(has(spot[1], spot[2]), "The journey misses: " .. spot[2])
end
print(string.format("PASS: %d journey checks (begins for new accounts, each node once, names Roblox accepts, dev accounts out, leaving's last node, a cap, wired into the intro)", checks))
process.exit(0)
