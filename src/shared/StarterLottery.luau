-- Server-owned, persisted onboarding rewards. Animation never determines a reward.
local GemRoller = require(script.Parent.GemRoller)
local Lottery = {}
Lottery.Version = 1
Lottery.GearOrder = { "Boots", "Gloves", "Weapon", "Shield", "Armor", "Helmet" }
Lottery.GemOrder = { "Boots", "Gloves", "Weapon", "Shield", "Armor", "Helmet", "Surge1", "Surge2", "Surge3" }
Lottery.Styles = { "Prospector", "Skirmisher", "Juggernaut" }
function Lottery.validChoice(style, element)
	return table.find(Lottery.Styles, style) ~= nil and GemRoller.PrototypeIds[element] ~= nil
end
-- Explicit choice is persisted before the reveal. Retrying never rerolls it.
function Lottery.prepareChoice(profile, style, element, generate)
	if profile.Intro.Lottery then return profile.Intro.Lottery end
	if not Lottery.validChoice(style, element) then return nil end
	local reward = { Version = 2, Style = style, Element = element, Gear = {}, Gems = {}, Granted = false }
	for _, slot in Lottery.GearOrder do
		table.insert(reward.Gear, { Slot = slot, Id = if slot == "Weapon" then "SwordShield" else "Armor" .. style .. slot .. "1" })
	end
	for index, slot in {"Surge1", "Surge2"} do
		local gem = generate(element)
		gem.Element, gem.Tier = element, "Common"
		gem.Size, gem.Clarity, gem.Cut = 1, 1, 1
		gem.SurgeTier, gem.SurgeRank, gem.CutMethod = 1, 1, "Starter"
		gem.Surge = GemRoller.PrototypeIds[element][index]
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
		if c[key] then
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
