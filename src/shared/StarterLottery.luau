-- Server-owned, persisted onboarding rewards. Animation never determines a reward.
local GemRoller = require(script.Parent.GemRoller)
local GemTraits = require(script.Parent.GemTraits)
local Lottery = {}
Lottery.Version = 1
Lottery.GearOrder = { "Boots", "Gloves", "Weapon", "Shield", "Armor", "Helmet" }
Lottery.GemOrder = { "Boots", "Gloves", "Weapon", "Shield", "Armor", "Helmet", "Surge1", "Surge2", "Surge3" }
Lottery.Styles = { "Prospector", "Skirmisher", "Juggernaut" }
-- What each key of a starter kit of this element can roll (catalog ids):
-- { Q, E, R }, each a list. With the triad, each key is one of two showcase
-- moves (GemTraits.Intro: the flashy ones, and R is a wall or an escape,
-- never a shield). Without it, the element's three classic surges.
local LANES = { "Offense", "Ability", "Defense" }
function Lottery.starterPools(element): { { string } }
	local intro = GemTraits.Enabled and GemTraits.Intro[element]
	if intro then
		local pools = {}
		for _, lane in LANES do
			table.insert(pools, table.clone(intro[lane]))
		end
		return pools
	end
	local pools = {}
	for _, id in GemRoller.StarterSurges[element] or {} do
		table.insert(pools, { id })
	end
	return pools
end
-- The kit's three moves, one from each pool. `pick(n)` picks 1..n (the
-- server's Random); without it, each pool's first.
function Lottery.rollMoves(element, pick: ((number) -> number)?): { string }
	local moves = {}
	for _, pool in Lottery.starterPools(element) do
		local index = if pick and #pool > 1 then math.clamp(pick(#pool), 1, #pool) else 1
		table.insert(moves, pool[index])
	end
	return moves
end
-- The moves a kit gives: what it rolled (saved on the reward), or for one
-- not rolled yet, each pool's first.
function Lottery.starterMoves(element, reward): { string }
	if reward and type(reward.Moves) == "table" and #reward.Moves == 3 then
		return table.clone(reward.Moves)
	end
	return Lottery.rollMoves(element)
end
function Lottery.validChoice(style, element)
	return table.find(Lottery.Styles, style) ~= nil and GemRoller.PrototypeIds[element] ~= nil
end
-- Explicit choice is persisted before the reveal. Retrying never rerolls it.
-- The moves are rolled here too (`pick`, see rollMoves) and saved with it.
function Lottery.prepareChoice(profile, style, element, generate, pick: ((number) -> number)?)
	if profile.Intro.Lottery then return profile.Intro.Lottery end
	if not Lottery.validChoice(style, element) then return nil end
	local moves = Lottery.rollMoves(element, pick)
	local reward = { Version = 4, Style = style, Element = element, Gear = {}, Gems = {}, Moves = moves, Granted = false }
	for _, slot in Lottery.GearOrder do
		table.insert(reward.Gear, { Slot = slot, Id = if slot == "Weapon" then "MatrixSwords1" else "Armor" .. style .. slot .. "1" })
	end
	-- With the triad on, the chosen element's three stones go where its keys
	-- are: the sword (Q), the core socket (E) and the shield (R).
	local slots = if GemTraits.Enabled then { "Weapon", "Surge2", "Shield" } else { "Surge1", "Surge2", "Surge3" }
	for index, slot in slots do
		local gem = generate(element)
		gem.Element, gem.Tier = element, "Common"
		gem.Size, gem.Clarity, gem.Cut = 1, 1, 1
		gem.SurgeTier, gem.SurgeRank, gem.CutMethod = 1, 1, "Starter"
		gem.Surge = GemRoller.StarterSurges[element][index]
		if GemTraits.Enabled and GemTraits.Matrix[element] then
			-- Every stone carries the rolled kit, so each key fires its move.
			gem.Traits = { Offense = moves[1], Ability = moves[2], Defense = moves[3] }
		end
		table.insert(reward.Gems, { Slot = slot, Gem = gem })
	end
	profile.Intro.Lottery = reward
	return reward
end
function Lottery.prepare(profile, rng, generate)
	if profile.Intro.Lottery then
		-- Already rolled (its gems are kept), but not yet claimed: the gear
		-- shown is whatever is equipped now (e.g. after a switched-off
		-- weapon was replaced).
		local reward = profile.Intro.Lottery
		if not reward.Granted then
			for _, entry in reward.Gear do
				entry.Id = profile.Character[entry.Slot]
			end
		end
		return reward
	end
	local reward = { Version = Lottery.Version, Gear = {}, Gems = {}, Granted = false }
	for _, slot in Lottery.GearOrder do
		table.insert(reward.Gear, { Slot = slot, Id = profile.Character[slot] })
	end
	local elements = { "Fire", "Frost", "Shock", "Poison" }
	for i = #elements, 2, -1 do
		local j = rng:NextInteger(1, i)
		elements[i], elements[j] = elements[j], elements[i]
	end
	for index, slot in Lottery.GemOrder do
		local gem = generate(elements[(index - 1) % #elements + 1])
		local roleIndex = ({Surge1 = 1, Surge2 = 2, Surge3 = 3})[slot]
		if GemRoller.Prototype and roleIndex then
			gem.Surge = GemRoller.PrototypeIds[gem.Element][roleIndex]
		end
		if GemRoller.RaritySurges and roleIndex then
			local used = {}
			for _, entry in reward.Gems do
				if string.sub(entry.Slot, 1, 5) == "Surge" and entry.Gem.Surge then used[entry.Gem.Surge] = true end
			end
			if used[gem.Surge] then
				for _, id in GemRoller.Pools[gem.Element] do
					if not used[id] then gem.Surge = id; break end
				end
			end
		end
		gem.Cut, gem.CutMethod = rng:NextInteger(5, 8), "Starter"
		if index == #Lottery.GemOrder then
			local upgraded = false
			for _, other in reward.Gems do
				if other.Gem.Tier ~= "Common" then
					upgraded = true
				end
			end
			if not upgraded and gem.Tier == "Common" then
				gem.Tier = "Uncommon"
			end
		end
		table.insert(reward.Gems, { Slot = slot, Gem = gem })
	end
	profile.Intro.Lottery = reward
	return reward
end
function Lottery.finish(profile, maxGems)
	local reward = profile.Intro.Lottery
	if not reward then
		return false, "Roll your starter kit first."
	end
	if reward.Granted then
		profile.Intro.Done = true
		return true
	end
	local overflow = 0
	for _, entry in reward.Gems do
		if profile.Character[entry.Slot .. "Gem"] then
			overflow += 1
		end
	end
	if #profile.Gems + overflow > maxGems then
		return false, "Make room in your gem backpack before claiming."
	end
	local c = profile.Character
	c.ItemGems = c.ItemGems or {}
	for _, entry in reward.Gems do
		local key = entry.Slot .. "Gem"
		-- (the triad retired the Q and R surge sockets: those stones go to the pouch)
		local retired = GemTraits.active(c) and table.find(GemTraits.ArchivedSockets, entry.Slot) ~= nil
		if c[key] or retired then
			table.insert(profile.Gems, entry.Gem)
		else
			c[key] = entry.Gem
			if c[entry.Slot] then
				c.ItemGems[entry.Slot] = c.ItemGems[entry.Slot] or {}
				c.ItemGems[entry.Slot][c[entry.Slot]] = entry.Gem
			end
		end
	end
	reward.Granted = true
	profile.Intro.Spun, profile.Intro.FirstStone, profile.Intro.Done = true, true, true
	return true
end
return Lottery
