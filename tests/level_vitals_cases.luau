local count = 0
local function check(ok, message) count += 1; assert(ok, message) end
local function equal(a, b) return math.abs(a - b) < 0.00001 end
check(Tree.vitals(nil).Health == 0 and Tree.vitals(nil).Stamina == 100, "Level one baseline")
check(Tree.vitals({Season={XP=90000}}).Charge == 100, "Season must not grant miner stats")
local profile = {Augments={XP=149}}
check(Tree.vitals(profile).Health == 0, "No early level bonus")
profile.Augments.XP = 150
check(Tree.vitals(profile).Health == 5 and Tree.vitals(profile).Stamina == 102 and Tree.vitals(profile).Charge == 102, "Level two gains all three vitals")
profile.Augments.XP = 1350
local v = Tree.vitals(profile)
check(v.Level == 10 and v.Health == 45 and v.Stamina == 118 and v.Charge == 118, "Existing level ten miner gets retroactive bonuses")
check(Tree.vitals(profile, "Even").Health == 0 and Tree.vitals(profile, "Even").Charge == 100, "Even matches normalize")
check(Tree.vitals(profile, "Full").Health == 45, "Full progression keeps bonuses")
check(Tree.vitals({Augments={XP=1e8}}).Health == (Tree.MaxLevel-1)*5, "Stats stop at miner level cap")

local player, hum, root, loadout = makePlayer(9001, Vector3.zero, nil)
profiles[player].Augments = {XP=1350,Unlocked={}}
Tree.initialize(profiles[player])
Players.PlayerAdded.Fire(player)
CombatServer.reset(player)
check(player:GetAttribute("Stamina") == 118 and player:GetAttribute("MaxCharge") == 118, "Reset publishes leveled maxima")
local st = CombatServer._state(player)
check(st.Resources.Stamina == 118 and st.Resources.Charge == 0, "Spawn starts stamina full and charge empty")
CombatServer.tutorialCharge(player)
check(st.Resources.Charge == 118, "Tutorial fills new Charge capacity")
st.Resources.Stamina = 110
player:SetAttribute("MatchStats", "Even")
check(st.Resources.Stamina == 100 and st.Resources.Charge == 100, "Entering even match clamps existing resources")
check(player:GetAttribute("MaxStamina") == 100 and player:GetAttribute("MaxCharge") == 100, "HUD matches normalized caps")
player:SetAttribute("MatchStats", "Full")
check(player:GetAttribute("MaxStamina") == 118 and st.Resources.Stamina == 100, "Full match restores capacity without free refill")
profiles[player].Augments.XP = 1500
player:SetAttribute("MinerLevel", 11)
check(player:GetAttribute("MaxCharge") == 120, "Live level-up immediately updates capacities")
profiles[player].Augments.XP = 0
player:SetAttribute("MinerLevel", 1)
check(player:GetAttribute("MaxCharge") == 100, "Switch to fresh miner removes previous bonuses")

Players.GetPlayerFromCharacter = function(_, character) return if character == player.Character then player else nil end
profiles[player].Augments.XP = 1350
player:SetAttribute("MinerLevel", 10)
root.Position = arena
loadout.WeaponGem = {Id="level-test",Element="Fire",Tier="Common",Size=1,Clarity=1,Cut=1}
st.Resources.Stamina, st.Resources.Charge = 115, 117
st.ResourceAt, st.StaminaRestUntil = now, 0
now += 1
CombatServer._tick(1)
check(st.Resources.Stamina == 118 and st.Resources.Charge == 117, "Regeneration supports over 100 without free Charge")
TriadServer.steal(player, st, {Root=root}, "Charge", 20, now)
check(st.Resources.Charge == 118, "Charge steals stop at leveled cap")
st.Resources.Stamina = 117
TriadServer.steal(player, st, {Root=root}, "Stamina", 20, now)
check(st.Resources.Stamina == 118, "Stamina steals stop at leveled cap")
local ratings = Classes.ratings(loadout)
local base = Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus)
hum.MaxHealth, hum.Health = base, base/2
applyStats(player.Character, loadout, profiles[player])
check(hum.MaxHealth == base+45 and equal(hum.Health/hum.MaxHealth, 0.5), "Avatar gains health and preserves damage fraction")
applyStats(player.Character, loadout, profiles[player])
check(hum.MaxHealth == base+45 and equal(hum.Health/hum.MaxHealth, 0.5), "Repeated application never stacks")
player:SetAttribute("MatchStats", "Even")
applyStats(player.Character, loadout, profiles[player])
check(hum.MaxHealth == base and equal(hum.Health/hum.MaxHealth, 0.5), "Even health removes only level bonus")
player:SetAttribute("MatchStats", nil)
applyStats(player.Character, loadout, profiles[player])
check(hum.MaxHealth == base+45, "Returning to lobby restores leveled health")
hum.Health = 0
applyStats(player.Character, loadout, profiles[player])
check(hum.Health == 0, "Stat refresh cannot revive defeated miner")
print("PASS: " .. count .. " miner-level vital checks (XP, migration, live caps, switching, health, PvP and reset)")
