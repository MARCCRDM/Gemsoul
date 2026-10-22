-- lune run tests/auto_equip_cases.luau <repo>
-- AUTO EQUIP (Shared.AutoEquip): Best is the most rating you can wear,
-- Balanced the most even, an element its affinity armor first and its
-- gems; owned pieces only, never another miner's, no shield under two
-- hands; Q/E/R gems kept unless a socket is empty; a plan applied leaves
-- nothing more to do.
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

local AutoEquip = shared("AutoEquip")
local Classes = shared("Classes")
local GearRolls = shared("GearRolls")
local GemConfig = shared("GemConfig")
local GemInventory = shared("GemInventory")
local Slots = shared("EquipmentSlots")

local function newProfile()
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
		},
		Owned = {
			Weapons = { MatrixSwords1 = 1, MatrixSwords6 = 1, ForgeGreataxe5 = 1, ForgeCleaver3 = 1 },
			Shields = { ScrapShield = 1, CrusaderShield = 1, ArmorJuggernautShield4 = 1 },
			Helmets = { ScrapHelmet = 1, CrusaderHelmet = 1, ArmorSkirmisherHelmet5 = 1, ArmorProspectorHelmet3 = 1 },
			Armors = { PaddedJack = 1, IronPlate = 1, ArmorJuggernautArmor5 = 1, ArmorSkirmisherArmor4 = 1 },
			Gloves = { ScrapGloves = 1, ArmorSkirmisherGloves5 = 1, ArmorJuggernautGloves2 = 1 },
			Boots = { ScrapBoots = 1, ArmorProspectorBoots5 = 1, ArmorJuggernautBoots3 = 1 },
		},
		Gems = {},
	}
	for _, slot in Slots.Order do
		profile.Character.ItemGems[slot] = {}
	end
	GearRolls.ensure(profile, Random.new(7))
	return profile
end

local function totalOf(loadout): number
	local r = Classes.ratings(loadout)
	local sum = 0
	for _, stat in Classes.StatNames do
		sum += r[stat].Base + r[stat].Bonus
	end
	return sum
end

-- What the server does with a plan (PlayerData.equipGear: the slot's gem
-- stays in the slot; PlayerData.socketGem: the old gem back to the pouch).
local function apply(profile, plan)
	local c = profile.Character
	for _, step in plan.Gear do
		local slot, id = step.Slot, step.Id
		local gems = c.ItemGems[slot]
		local held = c[slot .. "Gem"]
		if c[slot] then
			gems[c[slot]] = nil
		end
		c[slot] = id
		if held then
			gems[id] = held
		end
		c[slot .. "Gem"] = gems[id]
		c[slot .. "Quality"] = profile.Owned[Slots.Definitions[slot].Kind][id]
	end
	for _, step in plan.Gems do
		local gem
		for i, g in profile.Gems do
			if g.Id == step.Gem then
				gem = table.remove(profile.Gems, i)
				break
			end
		end
		assert(gem, "socketing a gem that isn't in the pouch: " .. step.Gem)
		if c[step.Slot .. "Gem"] then
			table.insert(profile.Gems, c[step.Slot .. "Gem"])
		end
		c[step.Slot .. "Gem"] = gem
		c.ItemGems[step.Slot][c[step.Slot]] = gem
	end
end

-- The modes ----------------------------------------------------------------------------------
check(#AutoEquip.Modes == 6, "Six modes: Best, Balanced and the four elements")
for _, mode in AutoEquip.Modes do
	check(AutoEquip.valid(mode), mode .. " isn't valid")
end
check(not AutoEquip.valid("Worst") and not AutoEquip.valid(nil) and not AutoEquip.valid(3), "Junk passed as a mode")
check(AutoEquip.label("Fire") == "THERMAL" and AutoEquip.label("Balanced") == "BALANCED", "Labels")
check(AutoEquip.plan({ Character = {}, Owned = {}, Gems = {} }, "Best").Changes == 0, "No class: nothing to plan")

-- Best: the most rating, a local best (no one swap beats it) --------------------------------
do
	local profile = newProfile()
	local before = totalOf(profile.Character)
	local plan = AutoEquip.plan(profile, "Best")
	check(plan.Mode == "Best" and #plan.Gear > 0, "Best changed nothing")
	check(plan.Rating > before and math.abs(plan.Gain - (plan.Rating - before)) < 1e-6, "Best didn't raise the rating")
	for i, step in plan.Gear do
		check(step.Slot ~= "Weapon" or i == 1, "The weapon goes first")
	end
	for _, step in plan.Gear do
		check(profile.Owned[Slots.Definitions[step.Slot].Kind][step.Id] ~= nil, "Planned a piece you don't own")
	end
	apply(profile, plan)
	check(math.abs(totalOf(profile.Character) - plan.Rating) < 1e-6, "The plan's rating isn't what you get")
	local now = totalOf(profile.Character)
	for _, slot in AutoEquip.GearOrder do
		local kind = Slots.Definitions[slot].Kind
		for id in profile.Owned[kind] do
			local trial = table.clone(profile.Character)
			trial[slot] = id
			trial[slot .. "Quality"] = profile.Owned[kind][id]
			check(totalOf(trial) <= now + 1e-6, "Swapping in " .. id .. " beats Best")
		end
	end
	check(AutoEquip.plan(profile, "Best").Changes == 0, "Best again had more to do")
end

-- Balanced: more even than Best, never more total --------------------------------------------
do
	local profile = newProfile()
	local best, balanced = AutoEquip.plan(profile, "Best"), AutoEquip.plan(profile, "Balanced")
	local function evenness(stats)
		local sum = 0
		for _, stat in Classes.StatNames do
			sum += math.log(math.max(stats[stat], 1) / math.max(best.Before[stat], 1))
		end
		return sum
	end
	check(best.Rating >= balanced.Rating - 1e-6, "Balanced out-rated Best")
	check(evenness(balanced.After) >= evenness(best.After) - 1e-6, "Balanced is less even than Best")
	local function spread(stats)
		local low, high = math.huge, 0
		for _, stat in Classes.StatNames do
			local ratio = stats[stat] / best.Before[stat]
			low, high = math.min(low, ratio), math.max(high, ratio)
		end
		return high / low
	end
	check(spread(balanced.After) < spread(best.After), "Balanced didn't even the stats out")
	apply(profile, balanced)
	check(AutoEquip.plan(profile, "Balanced").Changes == 0, "Balanced again had more to do")
end

-- An element: its affinity armor first --------------------------------------------------------
local function affinity(profile, slot, id, element)
	local roll = GearRolls.get(profile.Character, slot, id)
	local sum = 0
	for _, affix in roll and roll.Affixes or {} do
		if GemConfig.AffixById[affix.Id].Element == element then
			sum += affix.Bonus
		end
	end
	return sum
end
for _, element in GemConfig.Elements do
	local profile = newProfile()
	local plan = AutoEquip.plan(profile, element)
	apply(profile, plan)
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local kind = Slots.Definitions[slot].Kind
		local most = 0
		for id in profile.Owned[kind] do
			most = math.max(most, affinity(profile, slot, id, element))
		end
		check(
			math.abs(affinity(profile, slot, profile.Character[slot], element) - most) < 1e-6,
			element .. ": the " .. slot .. " isn't the most " .. element .. " one you own"
		)
	end
	check(AutoEquip.plan(profile, element).Changes == 0, element .. " again had more to do")
end
do -- (with affinity tied, the most rating)
	local profile = newProfile()
	local frost = AutoEquip.plan(profile, "Frost")
	local chosen
	for _, step in frost.Gear do
		if step.Slot == "Armor" then
			chosen = step.Id
		end
	end
	check(chosen == "ArmorSkirmisherArmor4", "Frost didn't take the Frost chest")
end

-- Two hands: no shield ------------------------------------------------------------------------
do
	local profile = newProfile()
	profile.Owned.Weapons = { ForgeGreataxe5 = 1 }
	profile.Character.Weapon = "ForgeGreataxe5"
	profile.Character.Shield = nil
	for _, mode in AutoEquip.Modes do
		local plan = AutoEquip.plan(profile, mode)
		for _, step in plan.Gear do
			check(step.Slot ~= "Shield", mode .. " put a shield under a two-handed weapon")
		end
	end
	-- From two hands to one: the weapon first, then the shield.
	profile.Owned.Weapons.ForgeCleaver3 = 1
	local plan = AutoEquip.plan(profile, "Best")
	local weaponAt, shieldAt
	for i, step in plan.Gear do
		weaponAt = if step.Slot == "Weapon" then i else weaponAt
		shieldAt = if step.Slot == "Shield" then i else shieldAt
	end
	check(weaponAt and shieldAt and weaponAt < shieldAt, "One hand again: the weapon, then a shield")
end

-- Another miner's piece stays theirs ----------------------------------------------------------
do
	local profile = newProfile()
	local free = AutoEquip.plan(profile, "Balanced")
	local wanted
	for _, step in free.Gear do
		if step.Slot == "Helmet" then
			wanted = step.Id
		end
	end
	check(wanted ~= nil, "(the fixture wants a helmet swap)")
	profile.Miners = { Active = 1, Slots = { { Character = {} }, { Character = { Helmet = wanted } } } }
	local plan = AutoEquip.plan(profile, "Balanced")
	for _, step in plan.Gear do
		check(not (step.Slot == "Helmet" and step.Id == wanted), "Took another miner's helmet")
	end
end

-- Gems ------------------------------------------------------------------------------------------
local function gem(id, element, tier, grade)
	return { Id = id, Element = element, Tier = tier, Size = grade, Clarity = grade, Cut = grade }
end
local function gemProfile()
	local profile = newProfile()
	local c = profile.Character
	c.WeaponGem = gem("q", "Fire", "Common", 2) -- Q
	c.ItemGems.Weapon[c.Weapon] = c.WeaponGem
	c.HelmetGem = gem("h", "Frost", "Common", 1)
	c.ItemGems.Helmet[c.Helmet] = c.HelmetGem
	profile.Gems = { -- (the pouch: socketed gems aren't in it)
		gem("leg", "Shock", "Legendary", 9),
		gem("rare", "Fire", "Rare", 6),
		gem("unc", "Poison", "Uncommon", 4),
		gem("rare2", "Shock", "Rare", 5),
		gem("raw", "Fire", "Legendary", 9),
	}
	profile.Gems[#profile.Gems].Cut = nil -- (uncut: it can't go in)
	return profile
end
do
	local profile = gemProfile()
	local loose = {}
	for _, g in GemInventory.available(profile) do
		loose[g.Id] = true
	end
	check(loose.leg and not loose.q and not loose.h, "(the fixture's pouch)")
	local plan = AutoEquip.plan(profile, "Best")
	local by, seen = {}, {}
	for _, step in plan.Gems do
		-- Loose, or one an earlier step took out (it's back in the pouch by then).
		check(loose[step.Gem], "Socketed a gem that isn't loose: " .. step.Gem)
		check(not seen[step.Gem], "One gem in two sockets")
		check(step.Gem ~= "raw", "Socketed an uncut gem")
		seen[step.Gem], by[step.Slot] = true, step.Gem
		local held = profile.Character[step.Slot .. "Gem"]
		if held then
			loose[held.Id] = true
		end
	end
	check(by.Gloves == "h" or by.Boots == "h", "The helmet's old gem didn't fill an empty socket")
	check(by.Weapon == nil, "Best swapped the sword's gem (your Q)")
	check(by.Armor == "leg", "The empty chest didn't get your most valuable gem")
	check(by.Helmet ~= nil and by.Helmet ~= "h", "The helmet kept a worse gem")
	apply(profile, plan)
	check(profile.Character.WeaponGem.Id == "q", "The Q gem moved")
	local again = AutoEquip.plan(profile, "Best")
	check(#again.Gems == 0, "Best again had gems to move")
end
do
	local profile = gemProfile()
	local plan = AutoEquip.plan(profile, "Fire")
	local by = {}
	for _, step in plan.Gems do
		by[step.Slot] = step.Gem
		local g
		for _, x in profile.Gems do
			g = if x.Id == step.Gem then x else g
		end
		check(g.Element == "Fire", "Thermal socketed a gem of another element")
	end
	check(by.Weapon == nil, "The sword's gem is Thermal already")
	check(by.Armor == "rare", "The chest didn't get your Thermal gem")
	apply(profile, plan)
	check(profile.Character.HelmetGem.Id == "h", "No Thermal gem left: the helmet keeps its own")
	local cryo = AutoEquip.plan(profile, "Frost")
	check(#cryo.Gems == 0, "Cryo with no Cryo gems loose moved one")
	local ion = AutoEquip.plan(profile, "Shock")
	local ionBy = {}
	for _, step in ion.Gems do
		ionBy[step.Slot] = step.Gem
	end
	check(ionBy.Weapon == "leg" and ionBy.Armor == "rare2", "Ion: its gems, most valuable first, Q, E then R")
end
do
	local profile = gemProfile()
	local by = {}
	for _, step in AutoEquip.plan(profile, "Balanced").Gems do
		by[step.Slot] = step.Gem
	end
	-- Thermal and Cryo are in already, Ion goes in the chest: the shield
	-- gets the Corrosive one over a second Thermal worth more.
	check(by.Armor == "leg" and by.Shield == "unc", "Balanced didn't spread the elements")
end

-- The server: Forge's "AutoEquip" request -----------------------------------------------------
do
	local profile = gemProfile()
	local calls, handlers = {}, {}
	local state = { build = true, enchant = true }
	local stubs = {
		TestAdmin = {},
		Equipment = {},
		Nearby = {},
		Progress = {},
		Combat = {
			canChangeBuild = function()
				return state.build
			end,
		},
		Enchanting = {
			canEnchant = function()
				return state.enchant
			end,
		},
		Shop = {
			register = function(name, fn)
				handlers[name] = fn
			end,
			reply = function(ok, message, extra)
				local out = extra or {}
				out.Ok, out.Message = ok, message
				return out
			end,
		},
		PlayerData = {
			get = function()
				return profile
			end,
			equipGear = function(_, kind, id)
				table.insert(calls, "gear:" .. Slots.ByKind[kind])
				apply(profile, { Gear = { { Slot = Slots.ByKind[kind], Id = id } }, Gems = {} })
				return true
			end,
			socketGem = function(_, gemId, slot)
				table.insert(calls, "gem:" .. slot)
				apply(profile, { Gear = {}, Gems = { { Slot = slot, Gem = gemId } } })
				return true
			end,
		},
	}
	local serverEnv = setmetatable({
		game = {
			GetService = function(_, service)
				return {
					Shared = names,
					PlayerRemoving = {
						Connect = function() end,
					},
				}
			end,
		},
		script = { Parent = names },
		require = function(name)
			return stubs[name] or shared(name)
		end,
	}, { __index = env })
	local Forge =
		luau.load(fs.readFile(ROOT .. "/src/server/Systems/Forge.luau"), { debugName = "Forge", environment = serverEnv })()
	Forge.start()
	local handler = handlers.AutoEquip
	check(handler ~= nil, "AutoEquip isn't registered")
	check(not handler({}, "Worst").Ok and not handler({}, nil).Ok, "Junk mode accepted")
	state.build = false
	check(not handler({}, "Best").Ok and #calls == 0, "Changed gear mid-match")
	state.build = true
	local plan = AutoEquip.plan(profile, "Best")
	local result = handler({}, "Best")
	check(result.Ok and result.Pieces == #plan.Gear and result.Gems == #plan.Gems, "The server didn't apply the plan")
	check(calls[1] == "gear:Weapon", "The weapon didn't go first")
	local seenGem = false
	for _, call in calls do
		check(not (seenGem and string.sub(call, 1, 5) == "gear:"), "Gear after gems")
		seenGem = seenGem or string.sub(call, 1, 4) == "gem:"
	end
	check(string.find(result.Message, "BEST build on", 1, true) ~= nil, "Says what it did: " .. tostring(result.Message))
	check(math.abs(result.Rating - plan.Rating) < 1e-6, "The rating it reports isn't the plan's")
	local again = handler({}, "Best")
	check(again.Ok and again.Pieces == 0 and string.find(again.Message, "nothing to change", 1, true), "Twice changed more")
	-- Away from Vey: the gear goes on, the gems wait.
	profile = gemProfile()
	table.clear(calls)
	state.enchant = false
	local away = handler({}, "Shock")
	check(away.Ok and away.Gems == 0 and string.find(away.Message, "Vey", 1, true), "Socketed away from Vey")
	for _, call in calls do
		check(string.sub(call, 1, 4) ~= "gem:", "Socketed away from Vey")
	end
end

print(string.format("PASS: %d auto equip checks (Best, Balanced, the elements, two hands, other miners, gems, the server)", checks))
