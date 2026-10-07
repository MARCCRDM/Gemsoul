--[[
	Gear presets (Shared.GearPresets): save what you're wearing to a slot,
	rename it, and switch to it in one tap.

	Two kinds (Shared.GearPresets.Parts): "Armor" loadouts and "Weapon"
	loadouts, three slots each.

	Request actions:
	  "PresetSave", part, slot, name?   save what you wear now (that part's
	                                    pieces) into slot 1-3
	  "PresetRename", part, slot, name
	  "PresetApply", part, slot         wear it (out of a fight: the Inventory)

	Between rounds of a Ranked match, Duels wears the picked loadouts through
	Presets.wear (the pivot window), so no free editing happens mid-match.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local GearPresets = require(ReplicatedStorage.Shared.GearPresets)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local Presets = {}

local function slotOf(value: any): number?
	if typeof(value) == "number" and value == math.floor(value) and value >= 1 and value <= GearPresets.Count then
		return value
	end
	return nil
end

local function partOf(value: any): string?
	return if typeof(value) == "string" and GearPresets.Parts[value] then value else nil
end

-- The player's loadouts of one part (repaired and stored back on the profile).
function Presets.list(player: Player, part: string)
	local profile = PlayerData.get(player)
	if not profile then
		return {}
	end
	local p: any = profile
	p.Presets = GearPresets.clean(p.Presets)
	return p.Presets[part] or {}
end

-- Out of fights only (the same rule as changing surges).
local function canChange(player: Player): boolean
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") or player:GetAttribute("MatchId") then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight(root.Position)
end

--[[
	Wears preset `slot`. Returns ok, a message, and how many changes it made.
	Pieces that are gone (sold, traded) are skipped and named.
]]
function Presets.wear(player: Player, part: string, slot: number): (boolean, string, number)
	local profile = PlayerData.get(player)
	local preset = profile and Presets.list(player, part)[slot]
	if not profile or not preset then
		return false, "That preset is empty.", 0
	end
	local steps, missing = GearPresets.plan(profile, preset)
	local done = 0
	for _, step in steps do
		if step.Kind == "Gear" then
			local weapon = Classes.weapon(profile.Character.Class, profile.Character.Weapon)
			local blocked = step.Slot == "Shield" and weapon and Classes.TwoHanded[weapon.WeaponType]
			if not blocked and PlayerData.equipGear(player, step.GearKind, step.Id) then
				done += 1
			else
				table.insert(missing, step.Slot)
			end
		elseif step.Kind == "Surge" then
			-- A gem on another surge key comes off it first (into the pouch).
			-- Looked up now, not from the plan: an earlier step may have
			-- already sent it back to the pouch.
			if not PlayerData.findGem(player, step.GemId) then
				for key, surgeSlot in GearPresets.SurgeSlots do
					local gem = (profile.Character :: any)[surgeSlot .. "Gem"]
					if key ~= step.Key and gem and gem.Id == step.GemId then
						PlayerData.unsocketSurge(player, key)
					end
				end
			end
			if PlayerData.socketSurge(player, step.GemId, step.Key) then
				done += 1
			else
				table.insert(missing, "Surge " .. step.Key)
			end
		elseif step.Kind == "Maneuver" then
			local node = Tree.Nodes[step.Id]
			if node and node.Branch == "RigManeuvers" and Tree.isLearned(profile, step.Id) then
				PlayerData.setManeuver(player, step.Index, step.Id)
				done += 1
			end
		end
	end
	PlayerData.sync(player)
	local message = if #missing > 0
		then string.format("%s on. Missing: %s.", preset.Name, table.concat(missing, ", "))
		else string.format("%s on.", preset.Name)
	return true, message, done
end

local function save(player: Player, part: any, slot: any, name: any)
	local profile = PlayerData.get(player)
	local kind, index = partOf(part), slotOf(slot)
	if not profile or not kind or not index then
		return reply(false, "Pick a loadout slot.")
	end
	local list = Presets.list(player, kind)
	local keep = if list[index] then list[index].Name else nil
	list[index] = GearPresets.capture(
		profile.Character,
		GearPresets.name(if typeof(name) == "string" and name ~= "" then name else keep, index, kind),
		kind
	)
	PlayerData.sync(player)
	return reply(true, "Saved " .. list[index].Name .. ".")
end

local function rename(player: Player, part: any, slot: any, name: any)
	local kind, index = partOf(part), slotOf(slot)
	local list = if kind then Presets.list(player, kind) else {}
	if not index or not list[index] then
		return reply(false, "Save a loadout there first.")
	end
	list[index].Name = GearPresets.name(name, index, kind)
	PlayerData.sync(player)
	return reply(true, "Renamed to " .. list[index].Name .. ".")
end

local function apply(player: Player, part: any, slot: any)
	local kind, index = partOf(part), slotOf(slot)
	if not kind or not index then
		return reply(false, "Pick a loadout slot.")
	end
	if not canChange(player) then
		return reply(false, "Switch loadouts in town, or between rounds of a Ranked match.")
	end
	local ok, message = Presets.wear(player, kind, index)
	return reply(ok, message)
end

function Presets.start()
	Shop.register("PresetSave", save)
	Shop.register("PresetRename", rename)
	Shop.register("PresetApply", apply)
end

return Presets
