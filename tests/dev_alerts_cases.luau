-- lune run tests/dev_alerts_cases.luau <repo>
-- The Owners' join alert (Server.DevAlerts, Client.DevAlerts): who counts as
-- new, what's said, and that only Owners are told (and never of themselves).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")
local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local fired, loaded = {}, nil
local players = {}
local stubs = {
	PlayerData = { Loaded = { Connect = function(_, fn) loaded = fn end }, get = function(p) return p.Profile end },
	Remotes = { DevAlert = { FireClient = function(_, to, data) table.insert(fired, { to, data }) end } },
	TestAdmin = { Playtest = { Owners = { 99 } } },
}
local published = 0
local services = {
	MessagingService = { SubscribeAsync = function() end, PublishAsync = function() published += 1 end },
	Players = { GetPlayers = function() return players end },
}
local Server = luau.load(fs.readFile(ROOT .. "/src/server/Systems/DevAlerts.luau"), {
	environment = setmetatable({
		game = { GetService = function(_, name) return services[name] end, JobId = "abcdef123" },
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function(name) return stubs[name] end,
		task = task,
	}, { __index = _G }),
})()
local function player(id, name, first)
	return { UserId = id, Name = name, DisplayName = name, Profile = { FirstJoin = first } }
end
local owner = player(99, "Dev", 1)
local newbie = player(1, "Sam", os.time() - 5)
local regular = player(2, "Kai", os.time() - 86400)
players = { owner, newbie, regular }
Server.start()
check(loaded ~= nil, "Not listening for joins")
loaded(newbie)
check(#fired == 1 and fired[1][1] == owner and fired[1][2].New == true and fired[1][2].Name == "Sam", "The Owner wasn't told of a new player")
loaded(regular)
check(#fired == 2 and fired[2][2].New == false, "A returning player called new")
loaded(owner)
check(#fired == 2, "An Owner's own join was announced")
task.wait(0.1)
check(published >= 2, "Not sent to the other servers")
-- What's said.
local Client = luau.load(fs.readFile(ROOT .. "/src/client/Modules/DevAlerts.luau"), {
	environment = setmetatable({
		game = { GetService = function() return { Shared = { Config = "Config" }, LocalPlayer = { UserId = 1 } } end },
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function() return { Playtest = {} } end,
	}, { __index = _G }),
})()
check(Client.line({ Name = "Sam", New = true }) == "New player! Sam just joined.", "Wrong line for a new player")
check(Client.line({ Name = "Kai", New = false }) == "Kai joined.", "Wrong line for a returning player")
print(string.format("PASS: %d dev alert checks", checks))
