--[[
	Gear presets (Shared.GearPresets): save what you're wearing to a slot,
	rename it, and switch to it in one tap.

	Two kinds (Shared.GearPresets.Parts): "Armor" loadouts and "Weapon"
	loadouts, three slots each.

	Each kind has an active slot: the loadout you're on. Every change to
	your gear, gems, surges or maneuvers saves into it (never mid-match), so
	a loadout is simply what you built while it was selected.

	Request actions:
	  "LoadoutSelect", part, slot       switch to that loadout: wear it, or,
	                                    when it's empty, start it from what
	                                    you wear now
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

-- All of the player's loadouts, repaired and stored back on the profile.
local function all(player: Player)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return nil
	end
	profile.Presets = GearPresets.clean(profile.Presets)
	return profile.Presets
end

-- The player's loadouts of one part.
function Presets.list(player: Player, part: string)
	local presets = all(player)
	return presets and presets[part] or {}
end

function Presets.active(player: Player, part: string): number
	local presets = all(player)
	return presets and presets.Active[part] or 1
end

-- Saves what the player wears into the active loadout of each kind.
-- Skipped while a loadout is being put on, and during matches.
local applying: { [Player]: boolean } = {}
function Presets.captureActive(player: Player)
	local profile = PlayerData.get(player)
	if profile and profile.Miners then return end
	local presets = all(player)
	if not profile or not presets or applying[player] or player:GetAttribute("MatchId") then
		return
	end
	for _, part in GearPresets.PartOrder do
		local slot = presets.Active[part]
		local list = presets[part]
		local name = if list[slot] then list[slot].Name else GearPresets.name(nil, slot, part)
		list[slot] = GearPresets.capture(profile.Character, name, part)
	end
end

-- Out of fights only (the same rule as changing surges).
local function canChange(player: Player): boolean
	return Combat.canChangeBuild(player)
end

--[[
	Wears preset `slot`. Returns ok, a message, and how many changes it made.
	Pieces that are gone (sold, traded) are skipped and named.
]]
function Presets.wear(player: Player, part: string, slot: number): (boolean, string, number)
	local profile = PlayerData.get(player)
	if profile and profile.Miners then return false, "Select a complete miner instead.", 0 end
	local preset = profile and Presets.list(player, part)[slot]
	if not profile or not preset then
		return false, "That preset is empty.", 0
	end
	-- Wearing a loadout makes it the active one; the steps below don't save
	-- into anything while they run.
	all(player).Active[part] = slot
	applying[player] = true
	local steps, missing = GearPresets.plan(profile, preset)
	local done = 0
	-- (Protected: a failing step must never leave autosave switched off.)
	local ok, problem = pcall(function()
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
	end)
	applying[player] = nil
	if not ok then
		warn("[Presets] wearing a loadout failed: " .. tostring(problem))
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
		return reply(false, "You can't switch loadouts during a fight or an expedition.")
	end
	local ok, message = Presets.wear(player, kind, index)
	return reply(ok, message)
end

local function selectLoadout(player: Player, part: any, slot: any)
	local kind, index = partOf(part), slotOf(slot)
	local profile = PlayerData.get(player)
	if not profile or not kind or not index then
		return reply(false, "Pick a loadout slot.")
	end
	if not canChange(player) then
		return reply(false, "You can't switch loadouts during a fight or an expedition.")
	end
	local label = GearPresets.Parts[kind].Label
	if Presets.list(player, kind)[index] then
		local ok, message = Presets.wear(player, kind, index)
		return reply(ok, message)
	end
	-- An empty slot: a new loadout, starting from what you wear. Changes
	-- you make now are saved into it.
	all(player).Active[kind] = index
	Presets.captureActive(player)
	PlayerData.sync(player)
	return reply(
		true,
		string.format("New %s loadout %d: swap pieces in and it saves as you go.", string.lower(label), index)
	)
end

function Presets.start()
	Shop.register("MinerSelect", function(player, index)
		if not canChange(player) or player:GetAttribute("DuelQueue") then
			return reply(false, "Switch miners in the Outpost, before you queue.")
		end
		local profile = PlayerData.get(player)
		if not profile or not profile.Intro.Done then return reply(false, "Finish your introduction first.") end
		local ok = PlayerData.selectMiner(player, index)
		return reply(ok, if ok then "Miner " .. index .. " is active." else "Choose a miner from 1 to 3.")
	end)
	Shop.register("LoadoutSelect", selectLoadout)
	-- Every change to what you wear saves into the active loadouts.
	-- A burst of changes (putting a loadout on) is one save and one sync.
	local queued: { [Player]: boolean } = {}
	PlayerData.CharacterChanged:Connect(function(player)
		if queued[player] then
			return
		end
		queued[player] = true
		task.defer(function()
			queued[player] = nil
			if player.Parent ~= nil then
				Presets.captureActive(player)
				PlayerData.sync(player)
			end
		end)
	end)
	Shop.register("PresetSave", save)
	Shop.register("PresetRename", rename)
	Shop.register("PresetApply", apply)
end

return Presets
