--[[
	AUTO EQUIP: the Inventory's one-tap build. Puts on the gear you own that
	fits a mode best and fills the gem sockets from your pouch. Pure: the
	server applies the plan (Forge's AutoEquip), the Inventory shows what it
	would do, tests check it.

	  AutoEquip.Modes            { "Best", "Balanced", "Fire", "Frost",
	                             "Shock", "Poison" }
	  AutoEquip.valid(mode)      -> is it one of them?
	  AutoEquip.label(mode)      -> "BEST", "BALANCED", "THERMAL"...
	  AutoEquip.rating(loadout)  -> its total rating
	  AutoEquip.plan(profile, mode) -> {
	      Mode,
	      Gear   { { Slot, Id } }       pieces to put on, the weapon first
	      Gems   { { Slot, Gem } }      loose gems to socket (Gem = its id)
	      Before, After { [stat]: n }   ratings (Base + Bonus), now and after
	      Rating, Gain                  the total after, and its change
	      Changes                       #Gear + #Gems
	  }

	The modes:
	  Best      the most total rating (Classes.ratings).
	  Balanced  the most even: the product of the four stats, each against
	            what you have now, so a fair lift to all beats a big lift
	            to one. Its gems spread over the elements.
	  An element (Fire, Frost, Shock, Poison: Thermal, Cryo, Ion,
	            Corrosive) armor whose affinity affixes are that element
	            first (GearRolls' Affixes), then the most rating; that
	            element's gems in every socket.

	Gear: owned, a piece of your class, not another miner's (MinerRoster),
	no shield under a two-handed weapon. Three passes over the slots, so a
	set bonus counts. A slot's gem stays in the slot when its piece
	changes (PlayerData.equipGear), so a swap never drops one.

	Gems: the sword's, chest's and shield's gems are Q, E and R, so Best and
	Balanced only fill those when they're empty; the helmet, gloves and
	boots take your most valuable loose gem (GemConfig.value) when it's
	worth more than theirs. An element build swaps every socket that isn't
	its element for its most valuable gem of it, while there are some.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)

local AutoEquip = {}

AutoEquip.Modes = { "Best", "Balanced", "Fire", "Frost", "Shock", "Poison" }
-- The weapon first: whether it takes both hands decides the shield.
AutoEquip.GearOrder = { "Weapon", "Armor", "Helmet", "Gloves", "Boots", "Shield" }
-- Q, E and R come from these sockets' gems.
AutoEquip.KeySlots = { Weapon = true, Armor = true, Shield = true }
-- Gems go in the key sockets first, then the rest.
AutoEquip.GemOrder = { "Weapon", "Armor", "Shield", "Helmet", "Gloves", "Boots" }
AutoEquip.Passes = 3

local MODE = {}
for _, mode in AutoEquip.Modes do
	MODE[mode] = true
end
local ELEMENT = { Fire = true, Frost = true, Shock = true, Poison = true }

function AutoEquip.valid(mode: any): boolean
	return type(mode) == "string" and MODE[mode] == true
end

function AutoEquip.label(mode: string): string
	if ELEMENT[mode] then
		return string.upper(GemConfig.elementName(mode))
	end
	return string.upper(mode)
end

local function ratingsOf(loadout)
	if not loadout.Class then
		return nil
	end
	local ok, result = pcall(Classes.ratings, loadout)
	return if ok then result else nil
end

local function statsOf(r): { [string]: number }
	local out = {}
	for _, stat in Classes.StatNames do
		out[stat] = if r then r[stat].Base + r[stat].Bonus else 0
	end
	return out
end

local function total(stats): number
	local sum = 0
	for _, stat in Classes.StatNames do
		sum += stats[stat]
	end
	return sum
end

local function twoHanded(loadout): boolean
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	return weapon ~= nil and Classes.TwoHanded[weapon.WeaponType] == true
end

-- How much of an element the armor carries: its affinity affixes' bonuses.
local function affinity(loadout, element: string): number
	local sum = 0
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		if slot == "Shield" and twoHanded(loadout) then
			continue
		end
		local roll = loadout[slot] and GearRolls.get(loadout, slot)
		for _, affix in roll and roll.Affixes or {} do
			local entry = GemConfig.AffixById[affix.Id]
			if entry and entry.Element == element then
				sum += affix.Bonus or 0
			end
		end
	end
	return sum
end

-- A build's score in a mode (higher is better).
local function scorer(mode: string, reference: { [string]: number })
	if mode == "Balanced" then
		return function(loadout)
			local stats = statsOf(ratingsOf(loadout))
			local sum = 0
			for _, stat in Classes.StatNames do
				sum += math.log(math.max(stats[stat], 1) / math.max(reference[stat], 1))
			end
			return sum
		end
	elseif ELEMENT[mode] then
		return function(loadout)
			-- The element first (in whole percents), the rating after.
			return math.floor(affinity(loadout, mode) * 100 + 0.5) * 100000 + total(statsOf(ratingsOf(loadout)))
		end
	end
	return function(loadout)
		return total(statsOf(ratingsOf(loadout)))
	end
end

-- The pieces you could put in a slot (owned, of your class, not another miner's).
local function candidates(profile, slot: string): { string }
	local kind = Slots.Definitions[slot].Kind
	local character = profile.Character
	local active = profile.Miners and profile.Miners.Active
	local list = {}
	for id, quality in profile.Owned and profile.Owned[kind] or {} do
		if not quality or not Classes.gear(character.Class, kind, id) then
			continue
		end
		local owner = MinerRoster.owner(profile, slot, id)
		if owner and owner ~= active then
			continue
		end
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

local function wear(profile, loadout, slot: string, id: string)
	local trial = table.clone(loadout)
	trial[slot] = id
	trial[slot .. "Quality"] = profile.Owned[Slots.Definitions[slot].Kind][id]
	return trial
end

-- The gem each slot holds after the swaps: the slot's own, else the
-- new piece's kept gem (PlayerData.equipGear).
local function gemsAfter(character, loadout): { [string]: any }
	local out = {}
	for _, slot in Slots.Order do
		local gem = character[slot .. "Gem"]
		if not gem and loadout[slot] then
			local kept = character.ItemGems and character.ItemGems[slot]
			gem = kept and kept[loadout[slot]] or nil
		end
		out[slot] = gem
	end
	return out
end

local function value(gem): number
	local ok, worth = pcall(GemConfig.value, gem)
	return if ok and type(worth) == "number" then worth else 0
end

local function planGems(profile, loadout, mode: string): { { Slot: string, Gem: string } }
	local now = gemsAfter(profile.Character, loadout)
	local pouch = {}
	for _, gem in GemInventory.available(profile) do
		if gem.Cut ~= nil and (not ELEMENT[mode] or gem.Element == mode) then
			table.insert(pouch, gem)
		end
	end
	local function byValue(a, b)
		local va, vb = value(a), value(b)
		if va ~= vb then
			return va > vb
		end
		return tostring(a.Id) < tostring(b.Id)
	end
	table.sort(pouch, byValue)
	local used, steps = {}, {}
	local elements = {} -- (Balanced: the elements already in the build)
	for _, slot in AutoEquip.GemOrder do
		if now[slot] and now[slot].Element then
			elements[now[slot].Element] = (elements[now[slot].Element] or 0) + 1
		end
	end
	for _, slot in AutoEquip.GemOrder do
		if not loadout[slot] or (slot == "Shield" and twoHanded(loadout)) then
			continue
		end
		local held = now[slot]
		local wants
		if ELEMENT[mode] then
			wants = not held or held.Element ~= mode
		elseif AutoEquip.KeySlots[slot] then
			wants = not held
		else
			wants = true
		end
		if not wants then
			continue
		end
		local pick
		for _, gem in pouch do
			if used[gem.Id] then
				continue
			end
			if mode == "Balanced" and pick == nil then
				pick = gem
			elseif mode == "Balanced" then
				-- A new element beats a repeat; the most valuable within each.
				local fresh = (elements[gem.Element] or 0) == 0
				local pickFresh = (elements[pick.Element] or 0) == 0
				if fresh and not pickFresh then
					pick = gem
				end
			else
				pick = gem
				break
			end
		end
		if pick and held and not ELEMENT[mode] and value(pick) <= value(held) then
			pick = nil -- (only for a better one)
		end
		if pick then
			used[pick.Id] = true
			if held and held.Element then
				elements[held.Element] -= 1
			end
			if held and held.Cut ~= nil and (not ELEMENT[mode] or held.Element == mode) then
				-- (back in the pouch, it can fill a socket further on)
				table.insert(pouch, held)
				table.sort(pouch, byValue)
			end
			elements[pick.Element] = (elements[pick.Element] or 0) + 1
			table.insert(steps, { Slot = slot, Gem = pick.Id })
		end
	end
	return steps
end

-- A loadout's total rating (what the plan's Rating counts).
function AutoEquip.rating(loadout): number
	return total(statsOf(ratingsOf(loadout or {})))
end

function AutoEquip.plan(profile, mode: string)
	mode = if AutoEquip.valid(mode) then mode else "Best"
	local character = profile and profile.Character or {}
	local before = statsOf(ratingsOf(character))
	local plan = {
		Mode = mode,
		Gear = {},
		Gems = {},
		Before = before,
		After = before,
		Rating = total(before),
		Gain = 0,
		Changes = 0,
	}
	if not profile or not character.Class then
		return plan
	end
	local score = scorer(mode, before)
	local loadout = table.clone(character)
	local options = {}
	for _, slot in AutoEquip.GearOrder do
		options[slot] = candidates(profile, slot)
	end
	for _ = 1, AutoEquip.Passes do
		local changed = false
		for _, slot in AutoEquip.GearOrder do
			if slot == "Shield" and twoHanded(loadout) then
				continue
			end
			local best, bestScore = loadout[slot], score(loadout)
			for _, id in options[slot] do
				if id ~= loadout[slot] then
					local trial = wear(profile, loadout, slot, id)
					local s = score(trial)
					if s > bestScore + 1e-6 then
						best, bestScore = id, s
					end
				end
			end
			if best ~= loadout[slot] then
				loadout = wear(profile, loadout, slot, best)
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	for _, slot in AutoEquip.GearOrder do
		if loadout[slot] ~= character[slot] and not (slot == "Shield" and twoHanded(loadout)) then
			table.insert(plan.Gear, { Slot = slot, Id = loadout[slot] })
		end
	end
	plan.Gems = planGems(profile, loadout, mode)
	plan.After = statsOf(ratingsOf(loadout))
	plan.Rating = total(plan.After)
	plan.Gain = plan.Rating - total(before)
	plan.Changes = #plan.Gear + #plan.Gems
	return plan
end

return AutoEquip
