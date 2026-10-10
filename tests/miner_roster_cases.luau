do
	local profile = { Character = { Class = "Warrior" }, Owned = {}, Gems = { { Id = "shared" } }, Coins = 500, Augments = { XP = 900 } }
	GearRolls.grant(profile, Classes.get("Warrior"), Random.new(11))
	assert(Slots.gearCount(profile) == 6, "Fresh account received extra default gear")
	profile.Character.Surge1Gem = { Id = "equipped", Size = 4 }
	local generated = 0
	local function starter(index)
		generated += 1
		local c = { Class = "Warrior" }
		for _, slot in Slots.Order do
			local kind = Slots.Definitions[slot].Kind
			local id = Slots.freeKey(profile.Owned[kind], profile.Character[slot])
			profile.Owned[kind][id] = 1
			c[slot], c[slot .. "Quality"] = id, 1
		end
		return c, { XP = 0 }
	end
	local roster = MinerRoster.initialize(profile, starter)
	assert(generated == 2 and Slots.gearCount(profile) == 18, "Roster must grant exactly two independent starter kits")
	MinerRoster.initialize(profile, starter)
	assert(generated == 2 and Slots.gearCount(profile) == 18, "Rejoin duplicated starter grants")
	local original = profile.Character.Weapon
	local maps = profile.Character.GearRolls
	assert(MinerRoster.owner(profile, "Weapon", original) == 1)
	assert(MinerRoster.switch(profile, 2))
	assert(profile.Augments.XP == 0 and profile.Character.Surge1Gem == nil, "New miner inherited old progression or Surge")
	assert(profile.Character.GearRolls == maps and profile.Coins == 500 and profile.Gems[1].Id == "shared", "Shared stash changed")
	profile.Augments.XP = 150
	profile.Character.Surge1Gem = { Id = "second" }
	assert(MinerRoster.switch(profile, 1))
	assert(profile.Augments.XP == 900 and profile.Character.Surge1Gem.Id == "equipped", "First miner lost their build")
	assert(MinerRoster.switch(profile, 2) and profile.Augments.XP == 150 and profile.Character.Surge1Gem.Id == "second")
	assert(not MinerRoster.switch(profile, 0) and not MinerRoster.switch(profile, 4) and not MinerRoster.switch(profile, "1"))
	assert(not MinerRoster.switch(profile, 1.5) and not MinerRoster.switch(profile, 0/0))
	assert(MinerRoster.owner(profile, "Weapon", original) == 1, "Other miner's equipped item became free")
	profiles[9001] = profile
	assert(not PlayerData.equipGear(9001, "Weapons", original), "One item equipped by two miners")
	for index = 1, 150 do assert(MinerRoster.switch(profile, 1 + index % 3)) end
	MinerRoster.capture(profile)
	assert(Slots.gearCount(profile) == 18 and #profile.Gems == 1, "Repeated swapping duplicated loot")
	for _, miner in roster.Slots do assert(miner.Character.GearRolls == nil and miner.Character.ItemGems == nil, "Shared maps duplicated into saved miners") end
	local dead = { [1] = true }
	assert(#MinerRoster.remaining(roster, dead) == 2)
	dead[3] = true
	assert(MinerRoster.remaining(roster, dead)[1] == 2)
	dead[2] = true
	assert(#MinerRoster.remaining(roster, dead) == 0 and #MinerRoster.remaining(roster, {}) == 3)
	assert(not MinerRoster.canCounter(1, 1) and MinerRoster.canCounter(1, 2) and MinerRoster.canCounter(nil, 1))
	print("PASS: miner migration, starter grants, independent progression, shared stash, exclusive equipment, 150 swaps and life/counter rules")
end
