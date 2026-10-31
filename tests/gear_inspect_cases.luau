-- lune run tests/gear_inspect_cases.luau <repo>
-- Another player's gear (Server.GearInspect, Client.GearInspect): what they
-- wear, piece by piece (name, rarity, stats, the gem in its socket), their
-- gear score; asked for from the card beside them (GEAR), only of someone
-- in the server, not too often.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
-- (Lune has no Random: a small seeded one with the same methods)
local Random = {
	new = function(seed)
		local state = (seed or 1) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
env = setmetatable({
	Random = Random,
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	NumberRange = roblox.NumberRange,
	Enum = roblox.Enum,
	game = {
		GetService = function()
			return {
				Shared = names,
				FindFirstChild = function()
					return nil
				end,
			}
		end,
	},
	script = { Parent = names },
	require = shared,
}, { __index = _G })


local Classes = shared("Classes")
local GearRolls = shared("GearRolls")
local Slots = shared("EquipmentSlots")

-- The server's summary, with the real gear.
local registered = {}
local others = {}
local profiles = {}
local clock = 100
local serverEnv = setmetatable({
	game = { GetService = function(_, name)
		if name == "Players" then
			return {
				GetPlayerByUserId = function(_, id) return others[id] end,
				PlayerRemoving = { Connect = function() end },
			}
		end
		return { Shared = names }
	end },
	script = { Parent = names },
	require = function(name)
		if name == "PlayerData" then
			return { get = function(p) return profiles[p] end }
		elseif name == "Shop" then
			return {
				register = function(n, fn) registered[n] = fn end,
				reply = function(ok, msg, extra) extra = extra or {}; extra.Ok, extra.Message = ok, msg; return extra end,
			}
		end
		return shared(name)
	end,
	os = setmetatable({ clock = function() return clock end }, { __index = os }),
}, { __index = env })
local Inspect = luau.load(fs.readFile(ROOT .. "/src/server/Systems/GearInspect.luau"), { debugName = "GearInspect", environment = serverEnv })()
Inspect.start()

local profile = {
	Character = {
		Class = "Warrior",
		Weapon = "MatrixSwords1",
		Shield = "ScrapShield",
		Helmet = "ScrapHelmet",
		Armor = "PaddedJack",
		Gloves = "ScrapGloves",
		Boots = "ScrapBoots",
		ItemGems = {},
		HelmetGem = { Id = "g1", Element = "Fire", Tier = "Rare", Cut = "Round", Purity = 0.5, Size = 1 },
	},
	Owned = {
		Weapons = { MatrixSwords1 = 1 }, Shields = { ScrapShield = 1 }, Helmets = { ScrapHelmet = 1 },
		Armors = { PaddedJack = 1 }, Gloves = { ScrapGloves = 1 }, Boots = { ScrapBoots = 1 },
	},
	Gems = {},
}
for _, slot in Slots.Order do
	profile.Character.ItemGems[slot] = {}
end
GearRolls.ensure(profile, Random.new(3))
local summary = Inspect.summary(profile)
check(#summary.Pieces == 6, "Not a card for each of the six pieces")
check(summary.Score == GearRolls.gearScore(profile.Character), "The gear score isn't theirs")
for i, slot in Slots.Order do
	local piece = summary.Pieces[i]
	check(piece.Slot == slot and piece.Label == Slots.Definitions[slot].Label, "The pieces aren't in the Armory's order")
	local gear = Classes.gear("Warrior", Slots.Definitions[slot].Kind, profile.Character[slot])
	check(piece.Name == gear.Name, slot .. ": not its name")
	check(piece.Rarity ~= nil and #piece.Stats > 0, slot .. ": no rarity or no stats")
end
check(summary.Pieces[1].Gem and summary.Pieces[1].Gem.Element == "Fire", "The helmet's gem isn't on its card")
check(summary.Pieces[2].Gem == nil, "A gem on a piece with an empty socket")
check(Inspect.summary({ Character = {} }).Pieces[1].Name == nil, "Nothing worn, a name anyway")

-- Asked for: someone in the server, not too often, nothing spare.
local them = { UserId = 9, DisplayName = "Kristen", GetAttribute = function(_, k) return if k == "MinerLevel" then 14 else nil end }
local me = { UserId = 1 }
others[9], profiles[them] = them, profile
local reply = registered.InspectGear(me, 9)
check(reply.Ok and reply.Name == "Kristen" and reply.Level == 14 and #reply.Pieces == 6, "Couldn't look at their gear")
check(reply.Owned == nil and reply.Gems == nil and reply.Coins == nil, "Sent more than what they wear")
check(not registered.InspectGear(me, 9).Ok, "Looked again straight away")
clock += 1
check(not registered.InspectGear(me, 12345).Ok, "Looked at someone not in the server")
clock += 1
check(not registered.InspectGear(me, "9").Ok, "Took a userId that isn't a number")

-- The client: a stat as shown.
local clientEnv = setmetatable({
	game = { GetService = function() return { Shared = names } end },
	script = { Parent = { GemClient = {}, IronUi = { Colors = {}, new = function() end }, UiKit = {} } },
	require = function(m) if type(m) == "table" then return m end return shared(m) end,
}, { __index = env })
local Client = luau.load(fs.readFile(ROOT .. "/src/client/Modules/GearInspect.luau"), { debugName = "GearInspectClient", environment = clientEnv })()
check(Client.statText("Health", 120) == "+120 HP" and Client.statText("Critical", 0.04) == "+4% Crit", "A stat isn't shown as it should be")
-- On the card beside them.
local card = fs.readFile(ROOT .. "/src/client/Modules/PlayerCard.luau")
check(card:find('require(script.Parent.GearInspect).open(target)', 1, true) ~= nil, "No GEAR on the card beside a miner")
check(fs.readFile(ROOT .. "/src/server/Main.server.luau"):find("Systems.GearInspect).start()", 1, true) ~= nil, "The server doesn't start GearInspect")
print(string.format("PASS: %d gear inspect checks (each piece, its gem, the gear score, someone in the server only, GEAR on the card)", checks))
