-- lune run tests/tutorial_cases.luau <repo>
-- The first-time tutorial (Shared.Tutorial, Systems/Intro): the kit is handed
-- out once, the five rocks drop the scripted gems in order and only when
-- you're standing by them, each beat ticks off only when it's really done
-- and only in order, and SKIP still gives the whole kit with Ember Lance on Q.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local function load(path, env)
	local base = setmetatable(env or {}, { __index = _G })
	return luau.load(fs.readFile(ROOT .. "/" .. path), { debugName = path, environment = base })()
end

-- Roblox stand-ins.
local Vector3 = {}
Vector3.__index = Vector3
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.new = v3
Vector3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return Vector3[key]
end
local CFrameMeta = {}
CFrameMeta.__index = CFrameMeta
local function cf(x, y, z)
	return setmetatable({ Position = v3(x, y, z) }, CFrameMeta)
end
CFrameMeta.__mul = function(a, b)
	return cf(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
end
local CFrame = {
	new = function(a, b, c)
		if type(a) == "table" then
			return cf(a.X, a.Y, a.Z)
		end
		return cf(a or 0, b or 0, c or 0)
	end,
}
local function typeofStub(value)
	if getmetatable(value) == CFrameMeta then
		return "CFrame"
	end
	return type(value)
end

local Tutorial = load("src/shared/Tutorial.luau", { Vector3 = { new = v3 } })

-- Rules ----------------------------------------------------------------------------------
local fresh = { Intro = { Done = false }, Character = {} }
check(Tutorial.beat(fresh).Id == "Mine", "A new player doesn't start by mining")
check(not Tutorial.advance(fresh, "OpenInventory"), "A later beat was ticked off first")
check(not Tutorial.advance(fresh, "Mine"), "Mining was ticked off before five gems")
local veteran = { Intro = { Done = true }, Character = {} }
check(Tutorial.beat(veteran) == nil, "An older save is sent through the tutorial again")
check(#Tutorial.Gems == 3 and Tutorial.Rocks == nil, "Use three finds from real rocks")
for _, beat in Tutorial.Beats do
	check(#beat.Prompt <= 60 and #(beat.Mobile or "") <= 60, "A prompt runs past two lines: " .. beat.Id)
end

-- Server flow ----------------------------------------------------------------------------
local function kinds()
	return { Weapons = {}, Armors = {}, Helmets = {}, Gloves = {}, Boots = {}, Shields = {} }
end
local profile = {
	Intro = { Done = false },
	Character = { GearRolls = kinds(), ItemGems = {} },
	Owned = kinds(),
	Gems = {},
}
local player = {
	UserId = 1,
	Character = nil,
	GetAttribute = function()
		return nil
	end,
}
local equipped = {}
local nextGem = 0
local handlers = {}
local spawnAt = cf(100, 5, 100)
local stubs = {
	Classes = {
		get = function()
			return { Armors = { { Id = "Padded" } }, Weapons = {} }
		end,
		starterWeapon = function()
			return { Id = "SwordShield" }
		end,
		weapon = function()
			return { Id = "SwordShield" }
		end,
	},
	Config = { OnlyClass = "Warrior", MaxGems = 200 },
	GemConfig = {},
	GemRoller = {
		setElement = function(gem, element)
			gem.Element = element
			return gem
		end,
	},
	GemGenerator = {
		generate = function(_, source, extra)
			return { Id = extra.Id, Source = source, Tier = "Rare", Size = 9, Clarity = 9, Cut = 9 }
		end,
	},
	Gems = {
		random = function()
			return {}
		end,
	},
	PlayerData = {
		get = function()
			return profile
		end,
		character = function()
			return profile.Character
		end,
		setLoadout = function(_, class, weapon)
			profile.Character.Class, profile.Character.Weapon = class, weapon
		end,
		setGearQuality = function(_, kind, id, quality)
			profile.Owned[kind][id] = quality
		end,
		equipGear = function(_, kind, id)
			equipped[kind .. id] = true
		end,
		addCoins = function(_, n)
			profile.Coins = (profile.Coins or 0) + n
		end,
		newGemId = function()
			nextGem += 1
			return "g" .. nextGem
		end,
		addGem = function(_, gem)
			table.insert(profile.Gems, gem)
			return true
		end,
		socketSurge = function(_, gemId, key)
			if key == "Q" then
				profile.Character.Surge1Gem = { Id = gemId }
			end
		end,
		sync = function() end,
		augmentsChanged = function() end,
		intro = function()
			return profile.Intro
		end,
	},
	Shop = {
		register = function(name, fn)
			handlers[name] = fn
		end,
		reply = function(ok, message, extra)
			local r = extra or {}
			r.Ok, r.Message = ok, message
			return r
		end,
	},
	TestAdmin = {
		allowed = function()
			return false
		end,
	},
	StarterLottery = load("src/shared/StarterLottery.luau", {
		script = { Parent = {} },
		require = function()
			return {}
		end,
	}),
	ExpandedItemTraits = {
		obtainable = function()
			return true
		end,
	},
	EquipmentSlots = load("src/shared/EquipmentSlots.luau"),
	GearRolls = {
		roll = function()
			return {}
		end,
	},
	ArmorFamilies = { ById = setmetatable({}, {
		__index = function()
			return "Skirmisher"
		end,
	}) },
	Tutorial = Tutorial,
	ArenaSessions = {
		enterTraining = function()
			return { Ok = true }
		end,
	},
	Market = {
		cantReceive = function()
			return nil
		end,
		give = function(_, item)
			profile.PurchasedItem = item
			return true
		end,
	},
}
local landmarks = {
	GetAttribute = function()
		return spawnAt
	end,
}
local ReplicatedStorage = {
	Shared = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}),
	FindFirstChild = function(_, name)
		return if name == "Landmarks" then landmarks else nil
	end,
}
local env = {
	game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			return { PlayerRemoving = { Connect = function() end } }
		end,
	},
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return stubs[name] or error("unstubbed " .. tostring(name))
	end,
	Random = {
		new = function()
			return {}
		end,
	},
	CFrame = CFrame,
	Vector3 = { new = v3 },
	typeof = typeofStub,
	os = os,
}
local Intro = load("src/server/Systems/Intro.luau", env)
Intro.start()

local begun = handlers.TutorialBegin(player)
check(begun.Ok and profile.Intro.Done and profile.Tutorial.Step == 1, "Begin didn't start the tutorial")
check(equipped.ArmorsArmorSkirmisherArmor1, "No starter chest was put on")
check(equipped.ShieldsArmorSkirmisherShield1 and equipped.WeaponsSwordShield, "No starter sword and shield")
local begunAgain = handlers.TutorialBegin(player)
check(begunAgain.Ok and #profile.Gems == 0, "Beginning twice handed things out twice")

-- Far from the rock: no gem.
player.Character = {
	FindFirstChild = function()
		return { Position = v3(0, 0, 0) }
	end,
}
check(not handlers.TutorialMine(player, 1).Ok and #profile.Gems == 0, "Mined a rock from across the map")
check(not handlers.TutorialMine(player, 9).Ok, "Mined a rock that doesn't exist")
check(not handlers.TutorialStep(player, "OpenInventory").Ok, "Skipped ahead of mining")

for index = 1, 3 do
 local result = Intro.tutorialMined(player)
 check(result and result.Gem, "Server mining hook failed")
end
check(#profile.Gems == 3, "Expected three gems")
check(Intro.tutorialMined(player) == nil, "Granted extra tutorial loot")
for i, spec in Tutorial.Gems do
	local gem = profile.Gems[i]
	check(gem.Element == spec.Element and gem.Tier == spec.Tier, "Gem " .. i .. " isn't the scripted one")
	check(gem.Surge == spec.Surge or spec.Surge == nil, "Gem " .. i .. " has the wrong Surge")
	check(gem.Cut and gem.Cut > 0, "Gem " .. i .. " is uncut (Surge slots need a cut gem)")
end
check(profile.Tutorial.Step == 2, "Mining five didn't move on")

check(handlers.TutorialStep(player, "GemIntro").Ok, "Gem introduction missing")
check(handlers.TutorialStep(player, "OpenInventory").Ok, "Opening the Inventory didn't tick off")
check(not handlers.TutorialStep(player, "SocketArmor").Ok, "The chest socket ticked off with nothing in it")
profile.Character.ArmorGem = profile.Gems[1]
check(handlers.TutorialStep(player, "SocketArmor").Ok, "The chest socket didn't tick off")
profile.Character.WeaponGem = profile.Gems[2]
check(handlers.TutorialStep(player, "SocketWeapon").Ok, "The sword socket didn't tick off")
profile.Character.ShieldGem = profile.Gems[3]
check(handlers.TutorialStep(player, "SocketShield").Ok, "The shield socket didn't tick off")
check(handlers.TutorialStep(player, "CloseInventory").Ok and profile.Tutorial.Done, "Enchanting should finish tutorial")
check(Tutorial.ById.SurgeQ == nil and Tutorial.ById.Queue == nil and Tutorial.ById.Play == nil, "Removed beats remain")
local migrated={Intro={Done=true}, Tutorial={Version=2,Step=12,Mined=5,Done=false},Character={}}
check(Tutorial.beat(migrated).Id == "GemIntro", "Old in-progress save stranded")

-- Skip from the very start: the whole kit, Ember Lance on Q.
profile = {
	Intro = { Done = false },
	Character = { GearRolls = kinds(), ItemGems = {} },
	Owned = kinds(),
	Gems = {},
}
local skipped = handlers.TutorialSkip(player)
check(skipped.Ok and profile.Tutorial.Done, "Skip did not finish")
check(#profile.Gems == 0, "Skip fabricated mining rewards")
check(handlers.TutorialSkip(player).Ok and #profile.Gems == 0, "Repeated skip changed inventory")

check(not handlers.AdminRestartTutorial(player).Ok, "Non-admin could restart tutorial")
stubs.TestAdmin.allowed = function()
	return true
end
stubs.PlayerData.unsocketGem = function(_, slot)
	local gem = profile.Character[slot .. "Gem"]
	if gem then
		table.insert(profile.Gems, gem)
		profile.Character[slot .. "Gem"] = nil
	end
	return gem
end
local coinsBefore = profile.Coins
local gemCount = #profile.Gems
check(handlers.AdminRestartTutorial(player).Ok, "Admin replay failed")
check(
	not profile.Tutorial.Done and profile.Tutorial.Step == 1 and profile.Tutorial.Mined == 0,
	"Replay didn't reset beats"
)
check(profile.Coins == coinsBefore and #profile.Gems >= gemCount, "Replay discarded existing progress")
local run = profile.Tutorial.Run
check(
	handlers.AdminRestartTutorial(player).Ok and profile.Tutorial.Run == run + 1,
	"Second replay has stale run identity"
)

print("PASS: " .. checks .. " tutorial checks (beats in order, scripted gems, rock reach, sockets, skip kit)")
