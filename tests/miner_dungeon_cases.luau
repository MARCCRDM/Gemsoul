do
	local p = squad(1)[1]
	permittedTester = p
	check(not handlers.DungeonMinerSelect(p, 2).Ok, "Reserve deployment outside dungeon")
	check(handlers.DungeonTest(p, "Full").Ok, "Roster test dungeon failed")
	local id = p:GetAttribute("DungeonId")
	tick(1)
	local drops = #encounterDrops
	check(dungeonLethal(p, p.Humanoid), "Lethal damage did not offer reserve")
	check(p.Humanoid.Health == 1 and p.Root.Anchored and p:GetAttribute("DungeonSelecting"), "Defeated miner not held safely")
	check(not handlers.DungeonMinerSelect(p, 1).Ok and not handlers.DungeonMinerSelect(p, "2").Ok, "Defeated or invalid miner accepted")
	tick(1)
	check(p:GetAttribute("DungeonId") == id and not worlds[id].Folder.Destroyed, "Dungeon ended with reserves available")
	check(handlers.DungeonMinerSelect(p, 3).Ok, "Remaining miner could not deploy")
	check(profiles[p].Miners.Active == 3 and p:GetAttribute("DungeonSelecting") == nil and not p.Root.Anchored, "Replacement did not regain control")
	check(p.Humanoid.Health == p.Humanoid.MaxHealth and #encounterDrops == drops + 1, "Replacement lacks full health or pod entrance")
	check(not handlers.DungeonMinerSelect(p, 2).Ok, "Repeated deployment while alive")
	check(dungeonLethal(p, p.Humanoid), "Second defeat skipped reserve")
	check(p:GetAttribute("DungeonAvailableMiners") == "2", "A defeated miner became available again")
	tick(31)
	check(profiles[p].Miners.Active == 2 and not p:GetAttribute("DungeonSelecting"), "Timed-out selection did not deploy final reserve")
	check(not dungeonLethal(p, p.Humanoid), "Fourth dungeon life granted")
	p.Humanoid.Health = 0
	tick(1)
	check(p:GetAttribute("DungeonId") == nil and worlds[id].Folder.Destroyed, "Final defeat did not end solo run")
	p.Humanoid.Health = p.Humanoid.MaxHealth
	check(handlers.DungeonTest(p, "Full").Ok, "New run could not start")
	tick(1)
	check(dungeonLethal(p, p.Humanoid) and p:GetAttribute("DungeonAvailableMiners") == "1,3", "Life use persisted into new run")
	ArenaSessions.leave(p)
	check(not p.Root.Anchored and not p:GetAttribute("DungeonSelecting"), "Leaving selection stranded the player")
	print("PASS: dungeon reserve choice, same-run survival, invalid requests, deployment, timeout, exhaustion, new-run reset and leave cleanup")
end
