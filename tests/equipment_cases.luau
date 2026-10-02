-- Run against the real shared modules and PlayerData socket functions.
local cases = 0
local function check(condition, message)
	assert(condition, message)
	cases += 1
end
local old = {
	Character = {
		Class = "Warrior",
		Weapon = "PistolShield",
		Armor = "PaddedJack",
		WeaponQuality = 3,
		ArmorQuality = 2,
		ArmorGem = { Id = "existing", Element = "Frost", Size = 2, Clarity = 2, Cut = 2 },
	},
	Owned = { Weapons = { PistolShield = 3 }, Armors = { PaddedJack = 2 } },
	Gems = {},
}
Slots.initialize(old)
check(old.Character.WeaponQuality == 3 and old.Character.ArmorQuality == 2, "Migration changed existing gear")
check(old.Character.ArmorGem.Id == "existing", "Migration removed enchantment")
Slots.initialize(old)
for _, slot in Slots.Order do
	check(old.Character[slot] ~= nil, "Missing starter item: " .. slot)
	local kind = Slots.Definitions[slot].Kind
	check(old.Owned[kind][old.Character[slot]] ~= nil, "Starter not owned")
	check(Classes.gear("Warrior", kind, old.Character[slot]) ~= nil, "Missing catalog item")
	check(Crafting.recipe == nil, "Retired crafting recipe still available")
	check(
		GemConfig.enchantment({ Element = "Frost", Size = 5, Clarity = 5, Cut = 5 }, slot) ~= nil,
		"Missing enchantment"
	)
end
local before = Classes.ratings(old.Character)
old.Character.BootsGem = { Id = "boots", Element = "Shock", Size = 5, Clarity = 5, Cut = 5 }
-- Gems no longer add flat ratings; a boots gem raises a defensive Ion Shield.
check(Classes.ratings(old.Character).Speed.Bonus == before.Speed.Bonus, "Gem still adds flat ratings")
check(GemConfig.stats(old.Character.BootsGem, "Boots").ShieldAmount == 10, "Boot gem shield missing")
local player = {}
profiles[player] = old
for _, slot in Slots.Order do
	old.Gems = { { Id = "new", Element = "Fire", Size = 1, Clarity = 1, Cut = 1 } }
	old.Character[slot .. "Gem"] = { Id = "prior", Element = "Frost", Size = 1, Clarity = 1, Cut = 1 }
	check(PlayerData.socketGem(player, "new", slot).Id == "new", "Socket rejected " .. slot)
	check(#old.Gems == 1 and old.Gems[1].Id == "prior", "Swap lost old gem")
	check(PlayerData.unsocketGem(player, slot).Id == "new" and #old.Gems == 2, "Unsocket lost gem")
end
check(PlayerData.socketGem(player, "prior", "Invalid") == nil, "Invalid slot accepted")
old.Gems = { { Id = "rough" } }
check(PlayerData.socketGem(player, "rough", "Helmet") == nil, "Rough gem accepted")
old.Character.HelmetGem = { Id = "full" }
old.Gems = { { Id = "a" }, { Id = "b" } }
check(PlayerData.unsocketGem(player, "Helmet") == nil and old.Character.HelmetGem.Id == "full", "Full pouch lost gem")
old.Gems = { { Id = "bound", Element = "Frost", Size = 2, Clarity = 2, Cut = 2 } }
local originalHelmet = old.Character.Helmet
old.Character.HelmetGem = nil
PlayerData.socketGem(player, "bound", "Helmet")
old.Owned.Helmets.SurveyHelmet = 1
check(
	PlayerData.equipGear(player, "Helmets", "SurveyHelmet") and old.Character.HelmetGem == nil,
	"Enchant transferred to replacement item"
)
check(
	PlayerData.equipGear(player, "Helmets", originalHelmet) and old.Character.HelmetGem.Id == "bound",
	"Original item lost its enchant"
)
check(
	PlayerData.unsocketGem(player, "Helmet").Id == "bound" and old.Character.ItemGems.Helmet[originalHelmet] == nil,
	"Unsocket left duplicate enchant"
)
local function rig(r15)
	local parts = {}
	local names = if r15
		then {
			"Head",
			"UpperTorso",
			"LowerTorso",
			"LeftUpperArm",
			"RightUpperArm",
			"LeftLowerArm",
			"RightLowerArm",
			"LeftHand",
			"RightHand",
			"LeftUpperLeg",
			"RightUpperLeg",
			"LeftLowerLeg",
			"RightLowerLeg",
			"LeftFoot",
			"RightFoot",
		}
		else { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
	for _, name in names do
		parts[name] = {
			Name = name,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(),
			FindFirstChildOfClass = function()
				return nil
			end,
			IsA = function(_self, k)
				return k == "BasePart"
			end,
			GetChildren = function()
				return {}
			end,
		}
	end
	return {
		FindFirstChild = function(_self, name)
			return parts[name]
		end,
		GetChildren = function()
			local result = {}
			for _, part in parts do
				table.insert(result, part)
			end
			return result
		end,
	}
end
local builds = 0
for _, r15 in { false, true } do
	for _, look in { "SuitScrap", "SuitMiner", "SuitRanger", "SuitCrusader", "SuitZeroG", "SuitThermal" } do
		for quality = 1, 4 do
			for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
				local before = built
				ArmorKits.build({}, rig(r15), look, Color3.fromRGB(80, 200, 220), quality, {
					Helmet = 5,
					VisorColor = Color3.fromRGB(120, 230, 190),
					FinishColor = Color3.fromRGB(210, 180, 70),
				}, slot)
				check(built - before >= 4, "Missing geometry for " .. slot)
				builds += 1
			end
		end
	end
end
print("PASS: " .. cases .. " equipment checks, including " .. builds .. " modular model builds")

local combinations = {}
local rarityCounts = { 0, 0, 0, 0, 0 }
local rng = Random.new(17423)
for player = 1, 300 do
	local profile = {
		Character = { Class = "Warrior", Weapon = "PistolShield", Armor = "PaddedJack" },
		Owned = { Weapons = { PistolShield = 1 }, Armors = { PaddedJack = 1 } },
		Gems = {},
	}
	check(GearRolls.grant(profile, Classes.List.Warrior, rng), "First loadout not rolled")
	local key = {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local roll = GearRolls.get(profile.Character, slot)
		check(profile.Character[slot] ~= Classes.List.Warrior[kind][1].Id, "Fixed basic starter retained")
		check(roll and roll.Rarity >= 1 and roll.Rarity <= 5, "Missing saved rarity")
		rarityCounts[roll.Rarity] += 1
		table.insert(key, profile.Character[slot] .. ":" .. roll.Rarity .. ":" .. roll.Finish .. ":" .. roll.Variant)
	end
	combinations[table.concat(key, ",")] = true
	local pistol = profile.Character.Weapon
	local prior = GearRolls.get(profile.Character, "Weapon")
	check(not GearRolls.grant(profile, Classes.List.Warrior, rng), "Reconnect rerolled loadout")
	check(
		profile.Character.Weapon == pistol and GearRolls.get(profile.Character, "Weapon") == prior,
		"Reconnect replaced item stats"
	)
end
local count = 0
for _ in combinations do
	count += 1
end
check(count >= 290, "Random sets lack diversity")
for i, rarity in GearRolls.Rarities do
	check(math.abs(rarityCounts[i] / 1800 - rarity.Weight / 100) < 0.05, "Rarity distribution outside tolerance")
end
print("PASS: 300 random player loadouts; " .. count .. " distinct sets; saved rolls stable; rarity distribution valid")
