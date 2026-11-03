-- lune run tests/dev_spectate_cases.luau <repo>
-- DEV > WATCH (Server.DevSpectate): watching, and JOIN into the dungeon the
-- one watched is in: Owners only, someone watched, in a Rift run; in, the
-- watching ends.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."
local checks = 0
local function check(v, m)
	checks += 1
	if not v then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(m) .. "\n")
		process.exit(1)
	end
end
local function signal()
	return { Connect = function() return { Disconnect = function() end } end }
end
local function player(id, name)
	local attrs = {}
	return {
		UserId = id, DisplayName = name, Parent = true, Character = nil, Attrs = attrs,
		GetAttribute = function(_, k) return attrs[k] end,
		SetAttribute = function(_, k, v) attrs[k] = v end,
		RequestStreamAroundAsync = function() end,
		CharacterAdded = signal(),
	}
end
local owner, other, stranger = player(1, "Owner"), player(2, "Kun"), player(3, "Rando")
local everyone = { owner, other, stranger }
local joined = nil
local riftAnswer = { true, "In Kun's Rift run." }
local registered = {}
local stubs = {
	DevAlerts = { owner = function(id) return id == 1 end },
	Shop = {
		reply = function(ok, message, extra) local r = extra or {}; r.Ok, r.Message = ok, message; return r end,
		register = function(name, fn) registered[name] = fn end,
	},
	RiftServer = { devJoin = function(o, t) joined = { o, t }; return riftAnswer[1], riftAnswer[2] end },
}
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then
			return {
				GetPlayers = function() return everyone end,
				GetPlayerByUserId = function(_, id) for _, p in everyone do if p.UserId == id then return p end end return nil end,
				PlayerAdded = signal(), PlayerRemoving = signal(),
			}
		end
		error("no service " .. n)
	end },
	workspace = { GetServerTimeNow = function() return 0 end },
	script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
	require = function(name) return stubs[name] or error("no stub " .. tostring(name)) end,
	task = { spawn = function() end, defer = function() end, wait = function() end },
}, { __index = _G })
local Spectate = luau.load(fs.readFile(ROOT .. "/src/server/Systems/DevSpectate.luau"), { debugName = "DevSpectate", environment = env })()
Spectate.start()
check(registered.DevSpectate and registered.DevSpectateJoin, "DevSpectateJoin isn't a request")

check(not Spectate.join(stranger).Ok, "Someone not an owner could join through WATCH")
check(not Spectate.join(owner).Ok and joined == nil, "JOIN went through with nobody watched")
check(Spectate.request(owner, 2).Ok, "Couldn't watch them")
check(not Spectate.join(owner).Ok and joined == nil, "JOIN went through with them not in a dungeon")
other:SetAttribute("RiftRun", "R7")
riftAnswer = { false, "Hop out of the mech first: it won't fit through." }
local refused = Spectate.join(owner)
check(not refused.Ok and refused.Message == riftAnswer[2], "The Rift's refusal wasn't passed on")
riftAnswer = { true, "In Kun's Rift run." }
local result = Spectate.join(owner)
check(result.Ok and joined[1] == owner and joined[2] == other, "JOIN didn't put the owner into their run")
check(not Spectate.join(owner).Ok, "Still watching after joining")
print(string.format("PASS: %d dev spectate checks (JOIN: owners only, someone watched, in a dungeon, the Rift's word passed on, the watching over)", checks))
