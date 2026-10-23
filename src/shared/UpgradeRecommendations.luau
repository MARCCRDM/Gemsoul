-- Recommendations only: never changes a profile. Both the client hints and
-- the server's explicit UpgradeSurges action use this same comparison.
local AutoEquip = require(script.Parent.AutoEquip)
local GemInventory = require(script.Parent.GemInventory)
local Traits = require(script.Parent.GemTraits)

local Recommendations = {}

local function usable(gem)
	return gem.Cut ~= nil and Traits.traitsOf(gem) ~= nil
end

local function metrics(gem)
	return { Traits.output(gem), gem.Size or 1, gem.Clarity or 1, gem.Cut or 1 }
end

-- A different move is a choice, not an upgrade. Require no weaker metric
-- (including ranked's normalized output), and at least one improvement.
local function improves(candidate, held, keys)
	if not held then
		return true
	end
	if candidate.Element ~= held.Element then
		return false
	end
	for _, key in keys do
		if Traits.traitFor(candidate, key) ~= Traits.traitFor(held, key) then
			return false
		end
	end
	local better = false
	local before = metrics(held)
	for i, value in metrics(candidate) do
		if value < before[i] then
			return false
		end
		better = better or value > before[i]
	end
	return better
end

local function score(gem)
	local m = metrics(gem)
	return m[1] * 1000 + m[2] + m[3] + m[4]
end

function Recommendations.surges(profile)
	local result = { Gems = {}, Keys = {}, Changes = 0 }
	local character = profile and profile.Character
	if not character or not character.Class or not Traits.active(character) then
		return result
	end
	local pouch = GemInventory.available(profile)
	table.sort(pouch, function(a, b)
		if score(a) ~= score(b) then
			return score(a) > score(b)
		end
		return tostring(a.Id) < tostring(b.Id)
	end)
	local used = {}
	for _, key in Traits.Keys do
		local slot = Traits.Sockets[key]
		if not character[slot] then
			continue
		end
		local keys = if key == "Q" and not character.Shield then { "Q", "R" } else { key }
		local held = character[slot .. "Gem"]
		for _, gem in pouch do
			if not used[gem.Id] and usable(gem) and improves(gem, held, keys) then
				used[gem.Id] = true
				table.insert(result.Gems, { Slot = slot, Gem = gem.Id })
				for _, affected in keys do
					result.Keys[affected] = true
				end
				break
			end
		end
	end
	result.Changes = #result.Gems
	return result
end

function Recommendations.inspect(profile)
	local best = AutoEquip.plan(profile, "Best")
	local surges = Recommendations.surges(profile)
	return { Best = best, Surges = surges, Equipment = best.Changes > 0, Any = best.Changes > 0 or surges.Changes > 0 }
end

return Recommendations
