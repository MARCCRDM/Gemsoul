-- lune run tools/dev_products_manifest.luau <repo>: every Store.RobuxProducts
-- key with its name and Robux price, as JSON (for tools/create_dev_products.py).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."
local cache = {}
local function load(name)
	if cache[name] then return cache[name] end
	local env = setmetatable({}, { __index = _G })
	env.Color3, env.Vector3, env.Vector2, env.UDim2, env.Enum, env.CFrame, env.NumberRange =
		roblox.Color3, roblox.Vector3, roblox.Vector2, roblox.UDim2, roblox.Enum, roblox.CFrame, roblox.NumberRange
	env.script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) }
	env.require = function(m) return load(type(m) == "string" and m or tostring(m)) end
	env.game = { GetService = function() return setmetatable({}, { __index = function() return {} end }) end }
	local mod = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
	cache[name] = mod
	return mod
end
local Store = load("Store")
local out = {}
for key in Store.RobuxProducts do
	local price = Store.robuxPrice(key)
	table.insert(out, { Key = key, Name = Store.productName(key) or key, Price = price })
end
table.sort(out, function(a, b) return a.Key < b.Key end)
print(serde.encode("json", out, true))
