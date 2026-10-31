-- The leaderboards and the Hall of Fame (Server.TopPlayers): the game's own
-- accounts (Devvolver, VolverDev, Config.Playtest's Owners) never on them.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local function player(id, name, display)
	return { UserId = id, Name = name, DisplayName = display or name }
end
local everyone = { player(11738957136, "Devvolver"), player(222, "VolverDev"), player(333, "kingreen113"), player(444, "trox111") }
local removedKeys, written = {}, {}
local function store(board)
	return {
		SetAsync = function(_, key, value) written[board .. ":" .. key] = value end,
		RemoveAsync = function(_, key) removedKeys[board .. ":" .. key] = true end,
		GetSortedAsync = function()
			return { GetCurrentPage = function()
				return { { key = "11738957136", value = 260 }, { key = "333", value = 527 }, { key = "222", value = 16 }, { key = "444", value = 3 } }
			end }
		end,
	}
end
local registered = {}
local services = {
	DataStoreService = { GetOrderedDataStore = function(_, name) return store(name) end },
	Players = {
		GetPlayers = function() return everyone end,
		GetNameFromUserIdAsync = function(_, id)
			for _, p in everyone do if p.UserId == id then return p.Name end end
			return "Player" .. id
		end,
	},
	ReplicatedStorage = { Shared = { Config = "Config", GemConfig = "GemConfig", Season = "Season", GearRolls = "GearRolls" } },
}
local stubs = {
	Config = { DataStoreName = "T", Features = {}, Playtest = { Owners = { 11738957136 }, Testers = {} } },
	GemConfig = { value = function() return 0 end },
	Season = { levelFor = function() return 1 end },
	GearRolls = { gearScore = function() return 0 end },
	PlayerData = { get = function(p)
		return { Gems = {}, Character = {}, Stats = { BestGem = 0, Kills = 0, GemsMined = p.UserId % 1000 }, Season = { XP = 0 } }
	end },
	Shop = { register = function(name, fn) registered[name] = fn end, reply = function(ok, msg, extra) extra = extra or {}; extra.Ok = ok; return extra end },
}
local waits = 0
local env = setmetatable({
	game = { GetService = function(_, name) return services[name] end },
	script = { Parent = { PlayerData = "PlayerData", Shop = "Shop" } },
	require = function(name) return stubs[name] end,
	task = { spawn = function(fn) fn() end, wait = function() waits += 1; if waits > 0 then error("stop") end end },
}, { __index = _G })
local Top = luau.load(fs.readFile(ROOT .. "/src/server/Systems/TopPlayers.luau"), { debugName = "TopPlayers", environment = env })()

check(Top.hidden(11738957136, "whoever"), "The owner's UserId isn't hidden")
check(Top.hidden(222, "volverdev") and Top.hidden(nil, "DEVVOLVER"), "VolverDev or Devvolver by name isn't hidden")
check(not Top.hidden(333, "kingreen113"), "A player was hidden")

pcall(Top.start) -- (refreshes once, then the loop's wait stops it)
local mined = Top.board("Mined")
local names = {}
for _, row in mined do
	table.insert(names, row.Name)
end
check(#mined == 2 and mined[1].Name == "kingreen113" and mined[2].Name == "trox111", "The boards still show the game's accounts: " .. table.concat(names, ", "))
check(removedKeys["T_Top_Mined:11738957136"] and removedKeys["T_Top_Mined:222"], "The hidden accounts' rows weren't taken off the store")
check(written["T_Top_Mined:333"] ~= nil and written["T_Top_Mined:11738957136"] == nil and written["T_Top_Mined:222"] == nil, "A hidden account's score was written")
print(string.format("PASS: %d leaderboard checks (the game's own accounts kept off every board)", checks))
