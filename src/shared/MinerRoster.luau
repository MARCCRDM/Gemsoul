-- Three characters, one account stash. Stored characters exclude shared item maps.
local Roster = {}
Roster.Count = 3
function Roster.valid(index)
	return type(index) == "number" and index == math.floor(index) and index >= 1 and index <= Roster.Count
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in value do out[key] = copy(child) end
	return out
end
function Roster.capture(profile)
	local roster = profile.Miners
	if not roster or not roster.Slots[roster.Active] then return end
	local character = {}
	for key, value in profile.Character do
		if key ~= "GearRolls" and key ~= "ItemGems" then character[key] = copy(value) end
	end
	local miner = roster.Slots[roster.Active]
	miner.Character, miner.Augments = character, copy(profile.Augments)
end
function Roster.initialize(profile, starter)
	if not profile.Miners then
		profile.Miners = { Version = 1, Active = 1, Slots = { { Name = "Miner 1" } } }
	end
	local roster = profile.Miners
	Roster.capture(profile)
	for index = 1, Roster.Count do
		if not roster.Slots[index] then
			local character, augments = starter(index)
			roster.Slots[index] = { Name = "Miner " .. index, Character = character, Augments = augments }
		end
	end
	return roster
end
function Roster.owner(profile, slot, id)
	if not id then return nil end
	local roster = profile.Miners
	if not roster then return nil end
	for index, miner in roster.Slots do
		local c = if index == roster.Active then profile.Character else miner.Character
		if c and c[slot] == id then return index end
	end
	return nil
end
function Roster.switch(profile, index)
	local roster = profile.Miners
	if not Roster.valid(index) or not roster or not roster.Slots[index] then return false end
	Roster.capture(profile)
	if index == roster.Active then return true end
	local maps, sockets = profile.Character.GearRolls, profile.Character.ItemGems
	profile.Character = copy(roster.Slots[index].Character)
	profile.Character.GearRolls, profile.Character.ItemGems = maps, sockets
	profile.Augments = copy(roster.Slots[index].Augments)
	roster.Active = index
	return true
end
-- Per-run state. Defeated miners stay unavailable until a new dungeon begins.
function Roster.remaining(roster, defeated)
	local available = {}
	for index = 1, Roster.Count do
		if roster and roster.Slots[index] and not defeated[index] then table.insert(available, index) end
	end
	return available
end
function Roster.canCounter(winner, team)
	return winner == nil or winner ~= team
end
return Roster
