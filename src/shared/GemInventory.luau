-- The loose stash only: equipped stones remain on their gear, never in the picker.
local Slots = require(script.Parent.EquipmentSlots)
local GemInventory = {}

function GemInventory.available(profile)
	if not profile then return {} end
	local used, seen, available = {}, {}, {}
	local function mark(gem)
		if type(gem) == "table" and gem.Id then used[gem.Id] = true end
	end
	local function loadout(character)
		if type(character) ~= "table" then return end
		for _, slot in Slots.Order do mark(character[slot .. "Gem"]) end
		for _, slot in Slots.SurgeOrder do mark(character[slot .. "Gem"]) end
		for _, byId in character.ItemGems or {} do
			if type(byId) == "table" then
				for _, gem in byId do mark(gem) end
			end
		end
	end
	loadout(profile.Character)
	local roster = profile.Miners
	for index, miner in roster and roster.Slots or {} do
		-- The active snapshot can lag behind an unsocket; Character is authoritative.
		if index ~= roster.Active then loadout(miner.Character) end
	end
	for _, gem in profile.Gems or {} do
		if type(gem) == "table" and gem.Id and not used[gem.Id] and not seen[gem.Id] then
			seen[gem.Id] = true
			table.insert(available, gem)
		end
	end
	return available
end

-- Loose gems of one rarity that no saved loadout names (Presets' Surge
-- gems): what selling every Common, or feeding them, may take in one go
-- without breaking a loadout.
function GemInventory.spare(profile, tier: string)
	local named = {}
	local presets = profile and profile.Presets
	if type(presets) == "table" then
		-- (An old save's single list, or the Armor and Weapon loadouts.)
		for _, list in { presets, presets.Armor, presets.Weapon } do
			for _, preset in if type(list) == "table" then list else {} do
				if type(preset) == "table" and type(preset.Surges) == "table" then
					for _, id in preset.Surges do
						named[id] = true
					end
				end
			end
		end
	end
	local spare = {}
	for _, gem in GemInventory.available(profile) do
		if gem.Tier == tier and not named[gem.Id] then
			table.insert(spare, gem)
		end
	end
	return spare
end

function GemInventory.find(profile, id)
	for _, gem in GemInventory.available(profile) do
		if gem.Id == id then return gem end
	end
	return nil
end

return GemInventory
