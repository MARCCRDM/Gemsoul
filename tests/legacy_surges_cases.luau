-- lune run tests/legacy_surges_cases.luau <repo>
-- Nothing in the surge archive (docs/surge-archive) may disappear: every
-- archived surge and maneuver must still exist in the catalog with its name
-- and icon, so gems players own keep working through the rework. New
-- abilities can be added freely; an archived one is only ever repurposed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local cache = {}
local function load(name)
	if cache[name] then
		return cache[name]
	end
	local env = setmetatable({
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		script = { Parent = setmetatable({}, { __index = function(_, key)
			return key
		end }) },
		require = function(module)
			return load(module)
		end,
	}, { __index = _G })
	cache[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { environment = env })()
	return cache[name]
end
local Tech = load("CombatTechnology")
local Icons = luau.load(fs.readFile(ROOT .. "/src/client/Modules/AbilityIconAtlas.luau"))()
local archive = serde.decode("json", fs.readFile(ROOT .. "/docs/surge-archive/legacy-surges.json"))

check(#archive.Abilities >= 47, "The archive lost abilities")
for _, entry in archive.Abilities do
	local definition = Tech.Catalog[entry.Id]
	check(definition ~= nil, entry.Id .. " was deleted from the catalog (archived abilities stay resolvable)")
	check(definition.Name == entry.Name, entry.Id .. " was renamed without updating the archive")
	check(Icons.Index[entry.Id] ~= nil, entry.Id .. " lost its icon")
end
check(fs.isFile(ROOT .. "/assets/images/ability_icons.png"), "The ability icon sheet is gone")

print("PASS: " .. checks .. " legacy surge checks (every archived surge and maneuver still resolves, named, with its icon)")
