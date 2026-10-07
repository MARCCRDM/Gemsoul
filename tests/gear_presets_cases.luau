-- lune run tests/gear_presets_cases.luau <repo>
-- Gear presets (Shared.GearPresets): capture, repair, the plan to wear one,
-- and the elements an opponent scouts.
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

local fire = { Id = "g-fire", Element = "Fire" }
local frost = { Id = "g-frost", Element = "Frost" }
local shock = { Id = "g-shock", Element = "Shock" }
local poison = { Id = "g-poison", Element = "Poison" }
local profile = {
	Character = {
		Weapon = "Sword",
		Shield = "Buckler",
		Helmet = "ScrapHelmet",
		Armor = "SuitScrap",
		Gloves = "ScrapGloves",
		Boots = "ScrapBoots",
		WeaponGem = fire,
		Surge1Gem = shock,
		Maneuvers = { "HydraulicSlam", "KineticRam", "StimDodge" },
	},
	Owned = {
		Weapons = { Sword = 1, Cleaver = 2 },
		Shields = { Buckler = 1 },
		Helmets = { ScrapHelmet = 1, ["ScrapHelmet#2"] = 3 },
		Armors = { SuitScrap = 1 },
		Gloves = { ScrapGloves = 1 },
		Boots = { ScrapBoots = 1 },
	},
	Gems = { frost, poison },
}

-- Capture: what's worn now.
local preset = GearPresets.capture(profile.Character, "Main")
check(preset.Gear.Weapon == "Sword" and preset.Gear.Boots == "ScrapBoots", "Gear not captured")
check(preset.Surges.Q == "g-shock" and preset.Surges.E == nil, "Surges not captured")
check(preset.Maneuvers[2] == "KineticRam", "Maneuvers not captured")
check(GearPresets.matches(profile.Character, preset), "A fresh capture doesn't match what's worn")
local steps, missing = GearPresets.plan(profile, preset)
check(#steps == 0 and #missing == 0, "Wearing what you wear took steps")

-- A different setup: a new weapon, a second helmet copy, Frost on E, Shock moved to R.
local other = {
	Name = "Burst",
	Gear = { Weapon = "Cleaver", Helmet = "ScrapHelmet#2", Boots = "SoldBoots" },
	Surges = { E = "g-frost", R = "g-shock", Q = "g-gone" },
	Maneuvers = { [3] = "KineticRam" },
}
steps, missing = GearPresets.plan(profile, other)
local kinds = {}
for _, step in steps do
	kinds[step.Kind .. ":" .. (step.Slot or step.Key or step.Index)] = step
end
check(kinds["Gear:Weapon"] and kinds["Gear:Weapon"].GearKind == "Weapons", "The weapon swap is missing")
check(kinds["Gear:Helmet"] and kinds["Gear:Helmet"].Id == "ScrapHelmet#2", "A second gear copy isn't worn")
check(table.find(missing, "Boots"), "Sold boots weren't reported missing")
check(kinds["Surge:E"] and kinds["Surge:E"].From == "Pouch", "A pouch gem isn't socketed from the pouch")
check(kinds["Surge:R"] and kinds["Surge:R"].From == "Q", "A gem on another key isn't moved")
check(table.find(missing, "Surge Q"), "A gone gem wasn't reported missing")
check(kinds["Maneuver:3"] and kinds["Maneuver:3"].Id == "KineticRam", "The maneuver swap is missing")
check(steps[1].Kind == "Gear" and steps[1].Slot == "Weapon", "The weapon isn't worn first (before the shield)")
check(not GearPresets.matches(profile.Character, other), "A different setup matches")

-- Repairing saved loadouts; an old single list of full presets is split.
local cleaned = GearPresets.clean({
	{
		Name = "  <b>Tank</b>  ",
		Gear = { Weapon = "Sword", Helmet = "ScrapHelmet", Boots = 7 },
		Surges = { Q = "x", Z = "y" },
	},
	"junk",
	{ Name = string.rep("L", 40), Gear = {} },
	{ Name = "Fourth", Gear = {} },
})
check(cleaned.Armor[1].Gear.Helmet == "ScrapHelmet" and cleaned.Armor[1].Gear.Weapon == nil, "Armor kept a weapon")
check(cleaned.Armor[1].Gear.Boots == nil and next(cleaned.Armor[1].Surges) == nil, "Armor kept junk or surges")
check(cleaned.Weapon[1].Gear.Weapon == "Sword" and cleaned.Weapon[1].Gear.Helmet == nil, "Weapon loadout wrong")
check(cleaned.Weapon[1].Surges.Q == "x" and cleaned.Weapon[1].Surges.Z == nil, "Surge keys weren't cleaned")
check(cleaned.Armor[1].Name == "Armor 1" and cleaned.Weapon[1].Name == "Weapons 1", "Split loadouts not renamed")
check(cleaned.Armor[2] == nil and cleaned.Weapon[4] == nil, "Junk or a fourth slot kept")
local again = GearPresets.clean({ Armor = { [2] = { Name = string.rep("L", 40), Gear = {} } }, Weapon = "junk" })
check(#again.Armor[2].Name == GearPresets.NameLength and next(again.Weapon) == nil, "New-shape repair")
check(GearPresets.name("", 2, "Weapon") == "Weapons 2" and GearPresets.name(nil, 1) == "Preset 1", "Default names")
check(next(GearPresets.clean(nil).Armor) == nil, "Nothing saved isn't empty")
-- Capturing one part only.
local armorOnly = GearPresets.capture(profile.Character, "A", "Armor")
check(armorOnly.Gear.Helmet and not armorOnly.Gear.Weapon and next(armorOnly.Surges) == nil, "Armor capture")
local weaponOnly = GearPresets.capture(profile.Character, "W", "Weapon")
check(weaponOnly.Gear.Weapon and not weaponOnly.Gear.Helmet and weaponOnly.Surges.Q == "g-shock", "Weapon capture")
check(GearPresets.matches(profile.Character, armorOnly) and #GearPresets.plan(profile, weaponOnly) == 0, "Part match")
check(GearPresets.label(armorOnly) == "4 pieces", "Armor label")

-- Scouting: every element worn, once, sorted.
local character = { WeaponGem = fire, HelmetGem = fire, Surge2Gem = poison, ArmorGem = shock }
local elements = GearPresets.elements(character)
check(#elements == 3 and elements[1] == "Fire" and elements[2] == "Poison" and elements[3] == "Shock", "Elements")
check(#GearPresets.elements({}) == 0, "No gems, no elements")
check(GearPresets.label(preset) == "6 gear  ·  1 surge", "Label")

print("PASS: " .. checks .. " gear preset checks (capture, plan, gear copies, surge moves, repair, scouting)")
