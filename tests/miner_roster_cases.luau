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
-- One miner (Config.Features.MinerRoster off, the beta): a new account gets
-- one, and an old save that holds three keeps them but plays only the active one.
do
	MinerRoster.configure(false)
	local made = 0
	local function starter()
		made += 1
		return { Class = "Warrior" }, { XP = 0 }
	end
	local fresh = { Character = { Class = "Warrior" }, Augments = { XP = 40 } }
	local roster = MinerRoster.initialize(fresh, starter)
	assert(made == 0 and #roster.Slots == 1 and roster.Active == 1, "One-miner account got extra miners")
	assert(MinerRoster.switch(fresh, 1) and not MinerRoster.switch(fresh, 2), "Switched to a miner that isn't there")
	assert(MinerRoster.remaining(roster, {})[1] == 1 and #MinerRoster.remaining(roster, { [1] = true }) == 0)
	assert(not MinerRoster.canCounter(1, 2) and not MinerRoster.canCounter(nil, 1), "Counter-pick with one miner")
	local old = {
		Character = { Class = "Warrior", Weapon = "b" },
		Augments = { XP = 300 },
		Miners = {
			Version = 1,
			Active = 2,
			Slots = {
				{ Name = "Miner 1", Character = { Class = "Warrior", Weapon = "a" }, Augments = { XP = 10 } },
				{ Name = "Miner 2" },
				{ Name = "Miner 3", Character = { Class = "Warrior", Weapon = "c" }, Augments = { XP = 20 } },
			},
		},
	}
	MinerRoster.initialize(old, starter)
	assert(made == 0 and #old.Miners.Slots == 3, "An old three-miner save lost or gained miners")
	assert(not MinerRoster.switch(old, 1) and not MinerRoster.switch(old, 3), "Switched away from the active miner")
	assert(MinerRoster.switch(old, 2) and old.Miners.Active == 2 and old.Augments.XP == 300, "Active miner changed")
	assert(MinerRoster.playable(old.Miners, 2) and not MinerRoster.playable(old.Miners, 1))
	local left = MinerRoster.remaining(old.Miners, {})
	assert(#left == 1 and left[1] == 2 and #MinerRoster.remaining(old.Miners, { [2] = true }) == 0, "Reserve deployed")
	assert(MinerRoster.owner(old, "Weapon", "a") == 1, "A resting miner's equipped gear became free")
	MinerRoster.configure(true)
	assert(MinerRoster.switch(old, 1) and old.Augments.XP == 10, "The other miners didn't come back with the roster")
	print("PASS: one-miner mode: no extra miners, no switch, no reserve, no counter-pick, old saves kept")
end
