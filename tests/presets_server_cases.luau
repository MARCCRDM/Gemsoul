-- lune run tests/presets_server_cases.luau <repo>
-- Live loadouts (Systems/Presets): picking a slot switches to it, an empty
-- slot starts a new loadout from what you wear, every change saves into the
-- active loadout, and nothing saves mid-match.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local GearPresets = luau.load(fs.readFile(ROOT .. "/src/shared/GearPresets.luau"), { debugName = "GearPresets" })()
-- The real rule for when a build can change (Combat.canChangeBuild).
local Combat = luau.load(fs.readFile(ROOT .. "/src/shared/Combat.luau"), {
	debugName = "Combat",
	environment = setmetatable({
		game = {
			GetService = function()
				return {
					FindFirstChild = function()
						return nil
					end,
				}
			end,
		},
		script = { Parent = { EquipmentBalance = "EquipmentBalance" } },
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r, G = g, B = b }
			end,
		},
		Vector3 = {
			new = function(x, y, z)
				return { X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }
			end,
		},
		require = function()
			return {}
		end,
	}, { __index = _G }),
})()

-- Stand-ins -------------------------------------------------------------------
local handlers = {}
local changed = {}
local syncs = 0
local profile = {
	Character = {
		Class = "Warrior",
		Weapon = "Sword",
		Shield = "Buckler",
		Helmet = "ScrapHelmet",
		Armor = "SuitScrap",
		Gloves = "ScrapGloves",
		Boots = "ScrapBoots",
		Maneuvers = { "HydraulicSlam", "KineticRam", "StimDodge" },
	},
	Owned = {
		Weapons = { Sword = 1, Cleaver = 1 },
		Shields = { Buckler = 1 },
		Helmets = { ScrapHelmet = 1, CrusaderHelmet = 1 },
		Armors = { SuitScrap = 1 },
		Gloves = { ScrapGloves = 1 },
		Boots = { ScrapBoots = 1, MagBoots = 1 },
	},
	Gems = {},
}
local PlayerData = {
	CharacterChanged = {
		Connect = function(_, fn)
			table.insert(changed, fn)
		end,
	},
	get = function()
		return profile
	end,
	sync = function()
		syncs += 1
	end,
	findGem = function()
		return nil
	end,
}
local attributes = {}
local player = {
	Parent = "Players",
	Character = nil,
	GetAttribute = function(_, key)
		return attributes[key]
	end,
}
-- Equipping fires CharacterChanged after the change, as the real one does.
function PlayerData.equipGear(_, kind, id)
	local slot = ({
		Weapons = "Weapon",
		Shields = "Shield",
		Helmets = "Helmet",
		Armors = "Armor",
		Gloves = "Gloves",
		Boots = "Boots",
	})[kind]
	if not profile.Owned[kind][id] then
		return false
	end
	profile.Character[slot] = id
	for _, fn in changed do
		fn(player)
	end
	return true
end
local stubs = {
	Classes = {
		weapon = function()
			return { WeaponType = "OneHanded" }
		end,
		TwoHanded = {},
	},
	Combat = Combat,
	GearPresets = GearPresets,
	AugmentTree = {
		Nodes = {},
		isLearned = function()
			return false
		end,
	},
	PlayerData = PlayerData,
	Shop = {
		register = function(name, fn)
			handlers[name] = fn
		end,
		reply = function(ok, message)
			return { Ok = ok, Message = message }
		end,
	},
}
local env = setmetatable({
	game = {
		GetService = function()
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
	-- Deferred work runs straight away here, so checks can follow each change.
	task = {
		defer = function(fn, ...)
			fn(...)
		end,
	},
	warn = function(...)
		error(table.concat({ ... }, " "))
	end,
}, { __index = _G })
local Presets =
	luau.load(fs.readFile(ROOT .. "/src/server/Systems/Presets.luau"), { debugName = "Presets", environment = env })()
Presets.start()

local function change(kind, id)
	PlayerData.equipGear(player, kind, id)
end

-- Slot 1 is active from the start: a change saves into it.
change("Helmets", "CrusaderHelmet")
check(Presets.active(player, "Armor") == 1, "Slot 1 isn't the starting loadout")
check(profile.Presets.Armor[1].Gear.Helmet == "CrusaderHelmet", "A change didn't save into armor loadout 1")
check(profile.Presets.Weapon[1].Gear.Weapon == "Sword", "The weapon loadout wasn't saved too")

-- Picking empty slot 2: a new loadout, starting from what you wear.
local reply = handlers.LoadoutSelect(player, "Armor", 2)
check(reply.Ok and Presets.active(player, "Armor") == 2, "Slot 2 didn't become the active loadout")
check(profile.Presets.Armor[2].Gear.Helmet == "CrusaderHelmet", "A new loadout didn't start from what's worn")
-- Building it: changes go into 2, and 1 keeps its own pieces.
change("Helmets", "ScrapHelmet")
change("Boots", "MagBoots")
check(
	profile.Presets.Armor[2].Gear.Helmet == "ScrapHelmet" and profile.Presets.Armor[2].Gear.Boots == "MagBoots",
	"Loadout 2 didn't save"
)
check(
	profile.Presets.Armor[1].Gear.Helmet == "CrusaderHelmet" and profile.Presets.Armor[1].Gear.Boots == "ScrapBoots",
	"Editing 2 changed 1"
)

-- Back to 1: its pieces go back on, and 2 is untouched.
reply = handlers.LoadoutSelect(player, "Armor", 1)
check(reply.Ok and Presets.active(player, "Armor") == 1, "Couldn't switch back to 1")
check(profile.Character.Helmet == "CrusaderHelmet" and profile.Character.Boots == "ScrapBoots", "Loadout 1 wasn't worn")
check(profile.Presets.Armor[2].Gear.Boots == "MagBoots", "Switching overwrote loadout 2 while wearing 1")

-- Armor and weapons switch separately.
handlers.LoadoutSelect(player, "Weapon", 3)
change("Weapons", "Cleaver")
check(
	profile.Presets.Weapon[3].Gear.Weapon == "Cleaver" and profile.Presets.Weapon[1].Gear.Weapon == "Sword",
	"Weapon loadouts mixed up"
)
check(profile.Presets.Armor[1].Gear.Helmet == "CrusaderHelmet", "A weapon change touched the armor loadout")

-- Mid-match nothing saves (the round break wears loadouts, it doesn't edit them).
attributes.MatchId = "D1"
change("Helmets", "ScrapHelmet")
check(profile.Presets.Armor[1].Gear.Helmet == "CrusaderHelmet", "A mid-match change saved into a loadout")
check(not handlers.LoadoutSelect(player, "Armor", 2).Ok, "Switched loadouts by hand mid-match")
attributes.MatchId = nil

-- In the Outpost lobby (far outside the town walls) loadouts still switch;
-- out in the field they don't.
local root = { Position = { X = 0, Y = 0, Z = 7000 } }
player.Character = {
	FindFirstChild = function(_, name)
		return if name == "HumanoidRootPart" then root else nil
	end,
}
attributes.Outpost = true
check(handlers.LoadoutSelect(player, "Armor", 1).Ok, "Couldn't switch loadouts in the Outpost lobby")
attributes.Outpost = nil
check(not handlers.LoadoutSelect(player, "Armor", 1).Ok, "Switched loadouts out in the field")
player.Character = nil

-- Bad requests.
check(
	not handlers.LoadoutSelect(player, "Boots", 1).Ok and not handlers.LoadoutSelect(player, "Armor", 4).Ok,
	"Bad slot accepted"
)
check(GearPresets.clean(profile.Presets).Active.Weapon == 3, "The active slots don't survive a repair")

print(
	"PASS: "
		.. checks
		.. " live loadout checks (switching, new loadouts, autosave, separate kinds, no mid-match saves, lobby)"
)
