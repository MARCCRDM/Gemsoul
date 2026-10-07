--[[
	Gear presets: a few saved setups you can switch between in one tap, in the
	Inventory any time out of a fight, and between rounds of a Ranked match
	(the pivot window; no free editing there, only a preset).

	Two kinds, three slots each, switched on their own:
	  Armor loadouts    helmet, chest suit, gloves, boots
	  Weapon loadouts   weapon, shield, the three Surge gems (Q / E / R) and
	                    the three Rig Maneuvers (1 / 2 / 3)
	Each piece keeps its own socketed gem, so the gems come along. Pure: the
	server applies the plan, the client shows it, tests check it.

	  GearPresets.Count                    slots per kind
	  GearPresets.PartOrder                { "Armor", "Weapon" }
	  GearPresets.capture(character, name, part?) -> what's worn now (only
	                                        that part's pieces when given)
	  GearPresets.clean(presets)           -> { Armor = {..}, Weapon = {..} },
	                                        repaired (an old single list of
	                                        full presets is split in two)
	  GearPresets.name(value, slot, part?) -> a safe preset name
	  GearPresets.plan(profile, preset)    -> { steps }, { missing } to wear it
	  GearPresets.matches(character, preset) -> already wearing it?
	  GearPresets.elements(character)      -> { "Fire", ... } the elements of
	                                        every socketed gem, sorted
	  GearPresets.label(preset)            -> a one-line summary
]]
local GearPresets = {}

GearPresets.Count = 3
GearPresets.NameLength = 16
GearPresets.GearSlots = { "Weapon", "Shield", "Helmet", "Armor", "Gloves", "Boots" }
GearPresets.GearKinds = {
	Weapon = "Weapons",
	Shield = "Shields",
	Helmet = "Helmets",
	Armor = "Armors",
	Gloves = "Gloves",
	Boots = "Boots",
}
GearPresets.SurgeSlots = { Q = "Surge1", E = "Surge2", R = "Surge3" }
GearPresets.SurgeOrder = { "Q", "E", "R" }
GearPresets.PartOrder = { "Armor", "Weapon" }
GearPresets.Parts = {
	Armor = { Label = "Armor", Gear = { "Helmet", "Armor", "Gloves", "Boots" }, Powers = false },
	Weapon = { Label = "Weapons", Gear = { "Weapon", "Shield" }, Powers = true },
}

function GearPresets.name(value: any, slot: number, part: string?): string
	local text = if type(value) == "string" then value else ""
	text = string.gsub(text, "[%c<>]", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		local spec = part and GearPresets.Parts[part]
		return (if spec then spec.Label else "Preset") .. " " .. slot
	end
	return string.sub(text, 1, GearPresets.NameLength)
end

function GearPresets.capture(character, name: string?, part: string?)
	local spec = part and GearPresets.Parts[part]
	local gear, surges = {}, {}
	for _, slot in if spec then spec.Gear else GearPresets.GearSlots do
		if type(character[slot]) == "string" then
			gear[slot] = character[slot]
		end
	end
	if spec and not spec.Powers then
		return { Name = name or spec.Label, Gear = gear, Surges = {}, Maneuvers = {} }
	end
	for key, slot in GearPresets.SurgeSlots do
		local gem = character[slot .. "Gem"]
		if type(gem) == "table" and type(gem.Id) == "string" then
			surges[key] = gem.Id
		end
	end
	local maneuvers = {}
	for i, id in character.Maneuvers or {} do
		if type(id) == "string" and i <= 3 then
			maneuvers[i] = id
		end
	end
	return { Name = name or "Preset", Gear = gear, Surges = surges, Maneuvers = maneuvers }
end

-- One list of presets, repaired; `part` keeps only its pieces.
local function cleanList(presets, part: string?)
	local spec = part and GearPresets.Parts[part]
	local out = {}
	if type(presets) ~= "table" then
		return out
	end
	for slot = 1, GearPresets.Count do
		local preset = presets[slot]
		if type(preset) == "table" and type(preset.Gear) == "table" then
			local clean = {
				Name = GearPresets.name(preset.Name, slot, part),
				Gear = {},
				Surges = {},
				Maneuvers = {},
			}
			for _, gearSlot in if spec then spec.Gear else GearPresets.GearSlots do
				if type(preset.Gear[gearSlot]) == "string" then
					clean.Gear[gearSlot] = preset.Gear[gearSlot]
				end
			end
			for key in GearPresets.SurgeSlots do
				if
					(not spec or spec.Powers)
					and type(preset.Surges) == "table"
					and type(preset.Surges[key]) == "string"
				then
					clean.Surges[key] = preset.Surges[key]
				end
			end
			for i = 1, 3 do
				if
					(not spec or spec.Powers)
					and type(preset.Maneuvers) == "table"
					and type(preset.Maneuvers[i]) == "string"
				then
					clean.Maneuvers[i] = preset.Maneuvers[i]
				end
			end
			out[slot] = clean
		end
	end
	return out
end

-- Drops anything malformed from the saved presets (old saves, tampering).
-- An old save was one list of full presets: each is split into an armor
-- loadout and a weapon loadout in the same slot.
function GearPresets.clean(presets)
	if type(presets) ~= "table" then
		return { Armor = {}, Weapon = {} }
	end
	if presets.Armor ~= nil or presets.Weapon ~= nil then
		return { Armor = cleanList(presets.Armor, "Armor"), Weapon = cleanList(presets.Weapon, "Weapon") }
	end
	local armor, weapon = cleanList(presets, "Armor"), cleanList(presets, "Weapon")
	for slot = 1, GearPresets.Count do
		if armor[slot] then
			armor[slot].Name = GearPresets.name(nil, slot, "Armor")
		end
		if weapon[slot] then
			weapon[slot].Name = GearPresets.name(nil, slot, "Weapon")
		end
	end
	return { Armor = armor, Weapon = weapon }
end

local function gemIn(list, id)
	for _, gem in list or {} do
		if type(gem) == "table" and gem.Id == id then
			return gem
		end
	end
	return nil
end

--[[
	What it takes to wear `preset`: an ordered list of steps
	  { Kind = "Gear", Slot, GearKind, Id }
	  { Kind = "Surge", Key, GemId, From = "Pouch" | <another surge key> }
	  { Kind = "Maneuver", Index, Id }
	and what can't be worn any more (sold, traded, gem gone) as { text }.
	Gear goes first (the weapon before the shield), surges last.
]]
function GearPresets.plan(profile, preset)
	local steps, missing = {}, {}
	local character = profile.Character
	local owned = profile.Owned or {}
	for _, slot in GearPresets.GearSlots do
		local id = preset.Gear[slot]
		local kind = GearPresets.GearKinds[slot]
		if id and character[slot] ~= id then
			if owned[kind] and owned[kind][id] ~= nil then
				table.insert(steps, { Kind = "Gear", Slot = slot, GearKind = kind, Id = id })
			else
				table.insert(missing, slot)
			end
		end
	end
	for _, key in GearPresets.SurgeOrder do
		local id = preset.Surges[key]
		local current = character[GearPresets.SurgeSlots[key] .. "Gem"]
		if id and not (current and current.Id == id) then
			local from = nil
			if gemIn(profile.Gems, id) then
				from = "Pouch"
			else
				for otherKey, otherSlot in GearPresets.SurgeSlots do
					local other = character[otherSlot .. "Gem"]
					if otherKey ~= key and other and other.Id == id then
						from = otherKey
					end
				end
			end
			if from then
				table.insert(steps, { Kind = "Surge", Key = key, GemId = id, From = from })
			else
				table.insert(missing, "Surge " .. key)
			end
		end
	end
	local worn = character.Maneuvers or {}
	for i = 1, 3 do
		local id = preset.Maneuvers[i]
		if id and worn[i] ~= id then
			table.insert(steps, { Kind = "Maneuver", Index = i, Id = id })
		end
	end
	return steps, missing
end

function GearPresets.matches(character, preset): boolean
	for _, slot in GearPresets.GearSlots do
		if preset.Gear[slot] and character[slot] ~= preset.Gear[slot] then
			return false
		end
	end
	for key, slot in GearPresets.SurgeSlots do
		local gem = character[slot .. "Gem"]
		if preset.Surges[key] and not (gem and gem.Id == preset.Surges[key]) then
			return false
		end
	end
	for i = 1, 3 do
		if preset.Maneuvers[i] and (character.Maneuvers or {})[i] ~= preset.Maneuvers[i] then
			return false
		end
	end
	return true
end

-- Every element a fighter carries: gems in their gear and on the Surge Array.
-- What the opponent scouts between rounds.
function GearPresets.elements(character): { string }
	local seen, list = {}, {}
	local function add(gem)
		if type(gem) == "table" and type(gem.Element) == "string" and not seen[gem.Element] then
			seen[gem.Element] = true
			table.insert(list, gem.Element)
		end
	end
	for _, slot in GearPresets.GearSlots do
		add(character[slot .. "Gem"])
	end
	for _, slot in GearPresets.SurgeSlots do
		add(character[slot .. "Gem"])
	end
	table.sort(list)
	return list
end

function GearPresets.label(preset): string
	if next(preset.Surges) == nil and next(preset.Maneuvers) == nil then
		local pieces = 0
		for _ in preset.Gear do
			pieces += 1
		end
		return string.format("%d piece%s", pieces, if pieces == 1 then "" else "s")
	end
	local pieces, surges = 0, 0
	for _ in preset.Gear do
		pieces += 1
	end
	for _ in preset.Surges do
		surges += 1
	end
	return string.format("%d gear  ·  %d surge%s", pieces, surges, if surges == 1 then "" else "s")
end

return GearPresets
