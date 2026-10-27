--[[
	COUNTER: between the rounds of a Ranked 1v1, the round's loser (both
	sides after a drawn round) may answer what beat them in one tap. Pure:
	Systems/CounterServer builds and applies the plan, the pivot screen
	(SocialUI) shows it, tests check it.

	What hurt you (CounterGear.threat):
	  "Taken"  the damage you took in the round, by element (CombatServer
	           counts it through the match), when any of it was elemental;
	  "Gear"   else what their gear hits with: their sword's gem on every
	           hit and on Q (weighs 3), their chest suit's on E and their
	           shield's on R (1 each).
	  Their armor's main element and the element that beats it (it hits
	  them for 125%, Shared.ElementMatchup) come along, as a tip.

	The counter changes your armor, never your moves (CounterGear.plan):
	  - resist gems: the helmet, gloves and boots sockets (no move rides on
	    them) take the gems from your pouch that cut what you take most, a
	    finer gem first (each armor gem resists its own element, ElementMatchup).
	    The sum is what counts, so a plan never leaves your armor's main
	    element weak to something they hit you with.
	  - armor pieces: a helmet, chest suit, gloves, boots or shield whose
	    Defense affixes are the elements you take (they power those resist
	    gems' enchantment), as long as the gear rating stays within a tenth
	    of what you wear.
	  Your sword, its gem, and your chest suit's and shield's gems (Q, E and
	  R) stay where they are.

	  CounterGear.threat(taken, foe) -> {
	      Source = "Taken" | "Gear" | nil,
	      Shares = { { Element, Share } }   elemental damage, largest first
	      Plain                              share of it with no element (Taken)
	      TheirMain, TheirWeak               their armor's element, what beats it
	  }
	  CounterGear.expected(loadout, threat) -> what their elements do to you,
	      on average (1 = full; 1.25 = weak; under 1 resisted)
	  CounterGear.plan(profile, threat) -> {
	      Element                            what it answers (their main one)
	      Gems   { { Slot, Gem, Element, Name, From, FromName } }
	      Gear   { { Slot, Id, Name, FromName, Affix } }
	      Before, After                      CounterGear.expected, now and after
	      Lines  { { Element, Share, Before, After } }   each element, now and after
	      Changes                            #Gems + #Gear
	      Note                               why nothing changes, when it doesn't
	  }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoEquip = require(ReplicatedStorage.Shared.AutoEquip)
local Classes = require(ReplicatedStorage.Shared.Classes)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)

local CounterGear = {}

-- The sockets a counter may fill: no Q, E or R rides on them.
CounterGear.GemSlots = { "Helmet", "Gloves", "Boots" }
-- The pieces it may swap (the shield only under a one-handed weapon).
CounterGear.GearSlots = { "Helmet", "Armor", "Gloves", "Boots", "Shield" }
-- What their gear hits with when the round left no record: the sword's gem
-- lands on every hit and on Q, the chest suit's on E, the shield's on R.
CounterGear.GearWeights = { Weapon = 3, Armor = 1, Shield = 1 }
-- A piece swap may not cost more than this share of the gear rating.
CounterGear.RatingFloor = 0.9
CounterGear.Passes = 2

local function twoHanded(loadout): boolean
	local ok, weapon = pcall(Classes.weapon, loadout.Class, loadout.Weapon)
	return ok and weapon ~= nil and Classes.TwoHanded[weapon.WeaponType] == true
end

local function sorted(weights): ({ { Element: string, Share: number } }, number)
	local total = 0
	for _, amount in weights do
		total += amount
	end
	local list = {}
	if total <= 0 then
		return list, 0
	end
	for element, amount in weights do
		if amount > 0 then
			table.insert(list, { Element = element, Share = amount / total })
		end
	end
	table.sort(list, function(a, b)
		if math.abs(a.Share - b.Share) > 1e-9 then
			return a.Share > b.Share
		end
		return a.Element < b.Element
	end)
	return list, total
end

function CounterGear.threat(taken: { [string]: number }?, foe)
	local threat = { Source = nil, Shares = {}, Plain = 0 }
	local elemental, plain = {}, 0
	for key, amount in taken or {} do
		if type(amount) == "number" and amount > 0 then
			if GemConfig.ElementLabels[key] then
				elemental[key] = (elemental[key] or 0) + amount
			else
				plain += amount
			end
		end
	end
	local shares, total = sorted(elemental)
	if total > 0 then
		threat.Source, threat.Shares = "Taken", shares
		threat.Plain = plain / (total + plain)
	elseif type(foe) == "table" then
		local weights = {}
		for slot, weight in CounterGear.GearWeights do
			local gem = foe[slot .. "Gem"]
			if type(gem) == "table" and GemConfig.ElementLabels[gem.Element] then
				weights[gem.Element] = (weights[gem.Element] or 0) + weight
			end
		end
		local list = sorted(weights)
		if #list > 0 then
			threat.Source, threat.Shares = "Gear", list
		end
	end
	if type(foe) == "table" then
		local armor = ElementMatchup.profile(foe)
		threat.TheirMain = armor.Main
		threat.TheirWeak = ElementMatchup.weakTo(armor.Main)
	end
	return threat
end

function CounterGear.expected(loadout, threat): number
	if not threat or #threat.Shares == 0 then
		return 1
	end
	local armor = ElementMatchup.profile(loadout)
	local sum = 0
	for _, entry in threat.Shares do
		sum += entry.Share * (ElementMatchup.against(entry.Element, armor))
	end
	return sum
end

local function gemName(gem): string
	local ok, name = pcall(GemConfig.displayName, gem)
	return if ok and type(name) == "string" then name else GemConfig.elementName(gem.Element or "") .. " Gem"
end

local function gearName(character, slot: string, id: string?): string?
	if not id then
		return nil
	end
	local ok, gear = pcall(Classes.gear, character.Class, Slots.Definitions[slot].Kind, id)
	return if ok and gear then gear.Name else id
end

-- How much of the threat a piece's Defense affixes cover (share-weighted).
local function cover(loadout, slot: string, id: string?, threat): number
	local roll = id and GearRolls.get(loadout, slot, id)
	local sum = 0
	for _, affix in roll and roll.Affixes or {} do
		local entry = GemConfig.AffixById[affix.Id]
		if entry and entry.Side == "Defense" then
			for _, share in threat.Shares do
				if share.Element == entry.Element then
					sum += share.Share * (affix.Bonus or 0)
				end
			end
		end
	end
	return sum
end

-- The pieces you could wear in a slot (owned, of your class, not another miner's).
local function candidates(profile, slot: string): { string }
	local kind = Slots.Definitions[slot].Kind
	local character = profile.Character
	local active = profile.Miners and profile.Miners.Active
	local list = {}
	for id, quality in profile.Owned and profile.Owned[kind] or {} do
		local ok, gear = pcall(Classes.gear, character.Class, kind, id)
		if not quality or not ok or not gear then
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

local function rating(loadout): number
	local ok, value = pcall(AutoEquip.rating, loadout)
	return if ok and type(value) == "number" then value else 0
end

local function lines(before, after, threat)
	local out = {}
	local was, now = ElementMatchup.profile(before), ElementMatchup.profile(after)
	for _, entry in threat.Shares do
		table.insert(out, {
			Element = entry.Element,
			Share = entry.Share,
			Before = (ElementMatchup.against(entry.Element, was)),
			After = (ElementMatchup.against(entry.Element, now)),
		})
	end
	return out
end

function CounterGear.plan(profile, threat)
	local character = profile and profile.Character
	local plan = {
		Element = threat and threat.Shares[1] and threat.Shares[1].Element,
		Gems = {},
		Gear = {},
		Before = 1,
		After = 1,
		Lines = {},
		Changes = 0,
		Note = nil,
	}
	if not character or not threat or #threat.Shares == 0 then
		plan.Note = "They fought without element gems: there's nothing to resist."
		return plan
	end
	local loadout = table.clone(character)
	plan.Before = CounterGear.expected(character, threat)

	-- Pieces first (a slot's gem stays in the slot when its piece changes).
	local floor = rating(character) * CounterGear.RatingFloor
	for _, slot in CounterGear.GearSlots do
		if not loadout[slot] or (slot == "Shield" and twoHanded(loadout)) then
			continue
		end
		local best, bestCover = loadout[slot], cover(loadout, slot, loadout[slot], threat)
		for _, id in candidates(profile, slot) do
			if id ~= loadout[slot] then
				local c = cover(loadout, slot, id, threat)
				if c > bestCover + 1e-6 then
					local trial = table.clone(loadout)
					trial[slot] = id
					trial[slot .. "Quality"] = profile.Owned[Slots.Definitions[slot].Kind][id]
					if rating(trial) >= floor then
						best, bestCover = id, c
					end
				end
			end
		end
		if best ~= loadout[slot] then
			table.insert(plan.Gear, {
				Slot = slot,
				Id = best,
				Name = gearName(character, slot, best),
				FromName = gearName(character, slot, loadout[slot]),
				Affix = math.floor(bestCover * 1000 + 0.5) / 10,
			})
			loadout[slot] = best
			loadout[slot .. "Quality"] = profile.Owned[Slots.Definitions[slot].Kind][best]
		end
	end

	-- Then the resist gems: each slot takes the pouch gem that cuts the most.
	local pouch = {}
	for _, gem in GemInventory.available(profile) do
		if gem.Cut ~= nil and GemConfig.ElementLabels[gem.Element] then
			table.insert(pouch, gem)
		end
	end
	local used = {}
	local chosen = {}
	for _ = 1, CounterGear.Passes do
		local changed = false
		for _, slot in CounterGear.GemSlots do
			if not loadout[slot] then
				continue
			end
			local held = loadout[slot .. "Gem"]
			local best, bestScore, bestGrade = held, CounterGear.expected(loadout, threat), ElementMatchup.gemResist(held)
			for _, gem in pouch do
				if used[gem.Id] and chosen[slot] ~= gem then
					continue
				end
				local trial = table.clone(loadout)
				trial[slot .. "Gem"] = gem
				local score = CounterGear.expected(trial, threat)
				local grade = ElementMatchup.gemResist(gem)
				if score < bestScore - 1e-6 or (math.abs(score - bestScore) <= 1e-6 and best ~= held and grade > bestGrade + 1e-9) then
					best, bestScore, bestGrade = gem, score, grade
				end
			end
			if best ~= held then
				-- (Only pouch gems move: one taken out of a socket goes to the
				-- pouch when the plan is worn, never into another socket, so
				-- the steps can be worn in any order.)
				if chosen[slot] then
					used[chosen[slot].Id] = nil
				end
				used[best.Id] = true
				chosen[slot] = best
				loadout[slot .. "Gem"] = best
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	for _, slot in CounterGear.GemSlots do
		local gem = chosen[slot]
		if gem and gem ~= character[slot .. "Gem"] then
			local from = character[slot .. "Gem"]
			table.insert(plan.Gems, {
				Slot = slot,
				Gem = gem.Id,
				Element = gem.Element,
				Name = gemName(gem),
				From = from and from.Element or nil,
				FromName = from and gemName(from) or nil,
			})
		end
	end

	plan.After = CounterGear.expected(loadout, threat)
	plan.Lines = lines(character, loadout, threat)
	plan.Changes = #plan.Gems + #plan.Gear
	if plan.Changes == 0 then
		local has = false
		for _, gem in pouch do
			if gem.Element == plan.Element then
				has = true
			end
		end
		plan.Note = if has
			then "Your armor already answers it as well as your gems can."
			else string.format(
				"No %s gems in your pouch to resist it.",
				GemConfig.elementName(plan.Element or "")
			)
	end
	return plan
end

return CounterGear
