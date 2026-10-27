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
	      Abilities                     how many of Gems are Q, E or R
	      Before, After { [stat]: n }   ratings (Base + Bonus), now and after
	      Rating, Gain                  the total after, and its change
	      Looks  { { Kind, Id } }       cosmetics to wear (AutoEquip.looks)
	      Changes                       #Gear + #Gems + #Looks
	  }
	  AutoEquip.power(gem)       -> how strong its moves are (Q, E and R)
	  AutoEquip.looks(profile)   -> { { Kind, Id } } your rarest skins

	Looks, in every mode (they never change stats): for each kind of look
	(Shared.Cosmetics: suit, weapon and shield skins, pickaxe, visor,
	helmet, trim and back piece) the rarest one you own goes on, when it's
	rarer than what you wear (so a pick of your own of the same rarity
	stays). Ties: the dearer one, then by name.

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

	Gems: the sword's, chest's and shield's gems are Q, E and R (Shared.
	GemTraits). Best gives them your strongest moves, whatever their
	element: the loose gems with the most power (AutoEquip.power: rarity
	first, then Size, Clarity and Cut), the strongest on Q, then
	E, then R, each only for a stronger one than it holds. An element build
	does the same with that element's gems only, and swaps out any of
	another element. Balanced keeps your Q, E and R and only fills one
	that's empty. The helmet, gloves and boots take your most valuable loose
	gem (GemConfig.value) when it's worth more than theirs (an element
	build: its most valuable of that element, over any of another).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
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

-- How strong a gem's moves are, whichever key it's on (GemTraits.stats):
-- its rarity first (its output, the "% power" its moves show, and a
-- Legendary's Flourish), then its grades within that rarity, each as much
-- as it adds (Size's potency, Clarity's durations, Cut's cooldown). The
-- grades never lift a gem past the next rarity.
function AutoEquip.power(gem): number
	if type(gem) ~= "table" or not GemTraits.traitsOf(gem) then
		return 0
	end
	local function grade(key: string): number
		return (math.clamp(tonumber(gem[key]) or 1, 1, 10) - 1) / 9
	end
	local weights = GemTraits.SizePotency + GemTraits.ClarityDuration + GemTraits.CutCooldown
	local grades = (
		GemTraits.SizePotency * grade("Size")
		+ GemTraits.ClarityDuration * grade("Clarity")
		+ GemTraits.CutCooldown * grade("Cut")
	) / weights
	return GemTraits.output(gem) + 0.09 * grades
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
		local key = AutoEquip.KeySlots[slot] == true
		if mode == "Balanced" and key and held then
			continue -- (Balanced keeps your Q, E and R)
		end
		-- A key socket's gem is ranked by its moves, the others by their worth.
		local rank = if key and mode ~= "Balanced" then AutoEquip.power else value
		local pick
		for _, gem in pouch do
			if used[gem.Id] or (key and rank == AutoEquip.power and rank(gem) <= 0) then
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
			elseif rank == value then
				pick = gem -- (the pouch is in order of worth)
				break
			elseif pick == nil or rank(gem) > rank(pick) + 1e-9 then
				pick = gem
			end
		end
		-- Only for a better one (a gem of another element always goes, in
		-- an element build).
		if pick and held and (not ELEMENT[mode] or held.Element == mode) and rank(pick) <= rank(held) + 1e-9 then
			pick = nil
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

-- Looks: the rarest you own of each kind, over what you wear.
AutoEquip.LookKinds = { "Suit", "Skin", "Shield", "Helmet", "Visor", "Pick", "Trim", "Back" }
local LOOK_RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
-- (the catalogue, loaded on first use: planning gear never needs it)
local Cosmetics = nil
local function catalogue()
	Cosmetics = Cosmetics or require(ReplicatedStorage.Shared.Cosmetics)
	return Cosmetics
end
local function lookRank(id): number
	local cosmetic = catalogue().get(id)
	return if cosmetic then LOOK_RANK[cosmetic.Rarity] or 0 else 0
end
function AutoEquip.looks(profile)
	local steps = {}
	local cosmetics = profile and profile.Cosmetics
	local owned = type(cosmetics) == "table" and cosmetics.Owned
	if type(owned) ~= "table" then
		return steps
	end
	local worn = catalogue().forMiner(cosmetics, profile.Character)
	local best = {}
	for id, has in owned do
		local cosmetic = has and Cosmetics.get(id)
		local kind = cosmetic and cosmetic.Kind
		if not kind or not table.find(AutoEquip.LookKinds, kind) then
			continue
		end
		local other = best[kind] and Cosmetics.List[best[kind]]
		local rank = lookRank(id)
		local better = not other
			or rank > lookRank(other.Id)
			or rank == lookRank(other.Id) and ((cosmetic.Robux or 0) > (other.Robux or 0)
				or (cosmetic.Robux or 0) == (other.Robux or 0) and cosmetic.Name < other.Name)
		if better then
			best[kind] = id
		end
	end
	for _, kind in AutoEquip.LookKinds do
		local id = best[kind]
		local now = worn[kind]
		local wearing = now and owned[now] and lookRank(now) or 0
		if id and id ~= now and lookRank(id) > wearing then
			table.insert(steps, { Kind = kind, Id = id })
		end
	end
	return steps
end

function AutoEquip.plan(profile, mode: string)
	mode = if AutoEquip.valid(mode) then mode else "Best"
	local character = profile and profile.Character or {}
	local before = statsOf(ratingsOf(character))
	local plan = {
		Mode = mode,
		Gear = {},
		Gems = {},
		Abilities = 0,
		Before = before,
		After = before,
		Rating = total(before),
		Gain = 0,
		Looks = {},
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
	for _, step in plan.Gems do
		if AutoEquip.KeySlots[step.Slot] then
			plan.Abilities += 1
		end
	end
	plan.After = statsOf(ratingsOf(loadout))
	plan.Rating = total(plan.After)
	plan.Gain = plan.Rating - total(before)
	plan.Looks = AutoEquip.looks(profile)
	plan.Changes = #plan.Gear + #plan.Gems + #plan.Looks
	return plan
end

return AutoEquip
