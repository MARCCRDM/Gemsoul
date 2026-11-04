-- The onboarding funnel (Systems/Funnel): each step once, in order, for new
-- accounts only.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
Funnel.log = function(player, step, name)
	table.insert(sent, { Player = player, Step = step, Name = name })
end
local function stepsFor(player)
	local out = {}
	for _, entry in sent do
		if entry.Player == player then
			table.insert(out, entry.Step .. ":" .. entry.Name)
		end
	end
	return table.concat(out, ",")
end
Funnel.start()

check(#Funnel.Steps == 13 and Funnel.Steps[1] == "Joined" and Funnel.Steps[13] == "Second duel", "Funnel steps changed")
check(table.concat(Funnel.Steps, ",") == "Joined,Kit,First fight,Round 1 won,Hunt bounty,Dungeon entered,Dungeon boss,Dungeon cleared,Lobby,First rock,First gem,Socketed,Second duel", "Not today's intro, in order")

-- A new account, all the way through: the kit, round 1, HUNT BOUNTY, the
-- first dungeon and its boss, then the lobby and the mines.
local new = makePlayer(1, "New")
profiles[new] = { Intro = { Done = false } }
PlayerData.Loaded:Fire(new)
check(stepsFor(new) == "1:Joined", "Join not logged: " .. stepsFor(new))
check(profiles[new].Funnel and profiles[new].Funnel.Joined, "Join not kept on the profile")
-- A client can't report any step (the old style picker's is gone too).
Remotes.Funnel.OnServerEvent:Fire(new, "Style")
Remotes.Funnel.OnServerEvent:Fire(new, "Second duel")
Remotes.Funnel.OnServerEvent:Fire(new, { "Kit" })
Remotes.Funnel.OnServerEvent:Fire(new, 5)
check(stepsFor(new) == "1:Joined", "A client logged a step")
check(Funnel.reach(new, "Kit"), "Kit refused")
check(not Funnel.reach(new, "Kit"), "Kit logged twice")
check(not Funnel.reach(new, "Made up") and not Funnel.reach(new, "Element") and not Funnel.reach(new, "Style"), "An unknown or retired step was logged")
-- In the Outpost before the fight (spawned there): not the lobby yet.
new:SetAttribute("Outpost", true)
check(not profiles[new].Funnel.Lobby, "Lobby logged before the first fight")
new:SetAttribute("Outpost", nil)
new:SetAttribute("FirstFight", true)
new:SetAttribute("DuelsPlayed", 1)
new:SetAttribute("FirstFight", nil)
check(profiles[new].Funnel["First fight"], "First fight end not logged")
check(not profiles[new].Funnel["Second duel"], "The first fight counted as the second duel")
check(Funnel.reach(new, "Round 1 won") and Funnel.reach(new, "Hunt bounty"), "Round 1 / HUNT BOUNTY refused")
-- Through the Outpost on the way into the dungeon (under the loading
-- screen): not the lobby yet either.
new:SetAttribute("Outpost", true)
check(not profiles[new].Funnel.Lobby, "Lobby logged on the way into the first dungeon")
new:SetAttribute("Outpost", nil)
check(Funnel.reach(new, "Dungeon entered") and Funnel.reach(new, "Dungeon boss") and Funnel.reach(new, "Dungeon cleared"), "Dungeon steps refused")
new:SetAttribute("Outpost", true)
check(profiles[new].Funnel.Lobby, "Lobby not logged once back from the dungeon")
PlayerData.Trained:Fire(new, "Mine")
PlayerData.Trained:Fire(new, "Hit") -- (not a funnel step)
PlayerData.Trained:Fire(new, "MineGem")
PlayerData.Trained:Fire(new, "Enchant")
PlayerData.Trained:Fire(new, "EquipSurge") -- (retired step)
PlayerData.Trained:Fire(new, "Mine")
new:SetAttribute("DuelsPlayed", 2)
new:SetAttribute("DuelsPlayed", 3)
check(
	stepsFor(new)
		== "1:Joined,2:Kit,3:First fight,4:Round 1 won,5:Hunt bounty,6:Dungeon entered,7:Dungeon boss,8:Dungeon cleared,9:Lobby,10:First rock,11:First gem,12:Socketed,13:Second duel",
	"Full run wrong: " .. stepsFor(new)
)

-- Rejoining: the steps already logged stay logged.
local before = #sent
local again = makePlayer(1, "New")
profiles[again] = profiles[new]
profiles[again].Intro.Done = true
PlayerData.Loaded:Fire(again)
again:SetAttribute("Outpost", true)
PlayerData.Trained:Fire(again, "Mine")
check(#sent == before, "A rejoin logged steps again")

-- Left partway, back later: carries on from where it stopped.
local partway = makePlayer(2, "Partway")
profiles[partway] = { Intro = { Done = false } }
PlayerData.Loaded:Fire(partway)
Funnel.reach(partway, "Kit")
local back = makePlayer(2, "Partway")
profiles[back] = profiles[partway]
profiles[back].Intro.Done = true
PlayerData.Loaded:Fire(back)
back:SetAttribute("FirstFight", true)
back:SetAttribute("FirstFight", nil)
check(
	stepsFor(partway) == "1:Joined,2:Kit" and stepsFor(back) == "3:First fight",
	"Rejoin didn't carry on: " .. stepsFor(back)
)

-- A player from before the funnel (intro already done): never counted.
local veteran = makePlayer(3, "Veteran")
profiles[veteran] = { Intro = { Done = true } }
PlayerData.Loaded:Fire(veteran)
Remotes.Funnel.OnServerEvent:Fire(veteran, "Style")
PlayerData.Trained:Fire(veteran, "Mine")
veteran:SetAttribute("FirstFight", true)
veteran:SetAttribute("FirstFight", nil)
check(stepsFor(veteran) == "" and profiles[veteran].Funnel == nil, "A returning player joined the funnel")

-- Not loaded yet: nothing happens, nothing breaks.
local early = makePlayer(4, "Early")
check(not Funnel.reach(early, "Joined"), "Logged without a profile")
Remotes.Funnel.OnServerEvent:Fire(early, "Style")

-- Roblox refusing a step doesn't stop the game (or the next steps).
local failing = makePlayer(5, "Failing")
profiles[failing] = { Intro = { Done = false } }
local realLog = Funnel.log
Funnel.log = function()
	error("analytics offline")
end
PlayerData.Loaded:Fire(failing)
check(profiles[failing].Funnel.Joined, "A failed send wasn't marked")
check(#warnings == 1 and string.find(warnings[1], "analytics offline", 1, true), "A failed send wasn't reported")
Funnel.log = realLog
check(Funnel.reach(failing, "Kit"), "The next step was blocked by a failed send")

print(
	"PASS: "
		.. checks
		.. " onboarding funnel checks (order, once each, client-reported steps, lobby after the first dungeon, the dungeon's steps, rejoins, returning players, failed sends)"
)
