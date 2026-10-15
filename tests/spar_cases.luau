-- Friendly sparring in the lobby (Shared.Spar, Server.SparServer) against
-- the real CombatServer: who can hit whom, the knock-down instead of a
-- death, getting back up, and the kit going away when it should.
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- The rules ---------------------------------------------------------------------------------------

check(Spar.canHit(true, true, false, false, false), "Two sparring players can't fight")
check(not Spar.canHit(true, nil, false, false, false), "A miner (kit away) can be hit")
check(not Spar.canHit(nil, true, false, false, false), "A miner (kit away) can hit")
check(not Spar.canHit(true, true, false, true, false), "A knocked-down player can be hit")
check(not Spar.canHit(true, true, true, false, false), "A knocked-down player can hit")
check(not Spar.canHit(true, true, false, false, true), "A player can hit themselves")
local ready = { Outpost = true, Alive = true, Seated = false }
check(Spar.startProblem(ready) == nil, "A free miner in the Outpost can't take the kit out")
check(Spar.startProblem({ Outpost = false, Alive = true, Seated = false }) ~= nil, "Sparred outside the Outpost")
check(
	Spar.startProblem({ Outpost = true, Alive = true, Seated = false, Busy = "CombatSession" })
		== "Finish your fight first.",
	"Sparred mid-fight"
)
check(Spar.startProblem({ Outpost = true, Alive = true, Seated = true }) ~= nil, "Sparred from a seat")
check(Spar.startProblem({ Outpost = true, Alive = false, Seated = false }) ~= nil, "Sparred while dead")
check(
	Spar.startProblem({ Outpost = true, Alive = true, Seated = false, Intro = true }) ~= nil,
	"Sparred before the intro was done"
)
check(Spar.stopWait({}, 50) == 0, "Free to put away untouched")
check(math.abs(Spar.stopWait({ Hurt = 49 }, 50) - (Spar.SheatheLock - 1)) < 1e-6, "Put away straight after a hit")
check(Spar.stopWait({ Hurt = 40 }, 50) == 0, "Kept out long after the last hit")
check(Spar.stopWait({ Down = 52 }, 50) == 2, "Put away while knocked down")

-- With the real CombatServer ----------------------------------------------------------------------

local outpost = Vector3.new(0, 5, 7000)
local a, ha, ra = makePlayer(1, outpost, nil)
local b, hb, rb = makePlayer(2, outpost + Vector3.new(0, 0, -5), nil)
local miner, hm, rm = makePlayer(3, outpost + Vector3.new(4, 0, -2), nil)
for _, entry in { { a, ha }, { b, hb }, { miner, hm } } do
	local player, humanoid = entry[1], entry[2]
	-- (Lobby players: no Arena opt-in.)
	player:SetAttribute("PvPEnabled", false)
	player:SetAttribute("Outpost", true)
	player.DisplayName = "P" .. player.UserId
	-- The real Humanoid reports every change in health.
	humanoid.HealthChanged = signal()
	local take = humanoid.TakeDamage
	function humanoid:TakeDamage(amount)
		take(self, amount)
		self.HealthChanged.Fire(self.Health)
	end
end
check(Combat.canFight(outpost), "The Outpost is a no-fight zone")
CombatServer.start()
SparServer.start()
local Spar_ = registered.Spar
check(Spar_ ~= nil, "Spar request not registered")

check(not CombatServer._canPvP(a, b), "Lobby players could fight without sparring")
check(Spar_(a, true).Ok and a:GetAttribute("Spar") == true, "Kit didn't come out")
check(
	not CombatServer._canPvP(a, b) and not CombatServer._canPvP(b, a),
	"A sparring player could hit a miner (or be hit)"
)
check(Spar_(b, true).Ok, "Second player couldn't spar")
check(CombatServer._canPvP(a, b) and CombatServer._canPvP(b, a), "Two sparring players couldn't fight")
check(not CombatServer._canPvP(a, miner) and not CombatServer._canPvP(miner, a), "A miner was in the spar")
-- Friends spar too: same party or team doesn't stop it.
a.Team, b.Team, a.Neutral, b.Neutral = "Blue", "Blue", false, false
check(CombatServer._canPvP(a, b), "Teammates couldn't spar")
a.Neutral, b.Neutral = true, true

-- A real blow lands.
local function swing(attacker, target)
	CombatServer._input(attacker, "BeginAttack")
	now += 0.1
	CombatServer._input(attacker, "ReleaseAttack", target.Character.HumanoidRootPart.Position)
	now += 1
end
local before = hb.Health
swing(a, b)
check(hb.Health < before, "A sparring blow did no damage")
check(type(b:GetAttribute("SparHurt")) == "number", "A hit didn't hold the kit out")
local refused = Spar_(b, false)
check(not refused.Ok and refused.Message:find("Still in the fight", 1, true), "Put the kit away mid-exchange")
-- A miner's swing never lands on a sparring player.
local minerBefore = ha.Health
swing(miner, a)
check(ha.Health == minerBefore, "A miner hurt a sparring player")

-- The finishing blow knocks down instead.
hb.Health = 1
local sent = #messages
swing(a, b)
check(hb.Health >= 1, "A spar killed")
check(Spar.isDown(b), "Not knocked down at 0 health")
local ko = nil
for i = sent + 1, #messages do
	if messages[i][1] == "SparKO" then
		ko = messages[i]
	end
end
check(ko ~= nil and ko[2] == b.UserId and ko[3] == a.UserId, "No knock-down message, or the wrong names in it")
check(not CombatServer._canPvP(a, b), "A downed player could be hit")
check(not CombatServer._canPvP(b, a), "A downed player could hit")
local aBefore = ha.Health
swing(b, a)
check(ha.Health == aBefore, "A downed player's swing landed")
check(not Spar_(b, false).Ok, "Put the kit away while down")
-- Up again: full health, still sparring.
SparServer._getUp(b, hb)
check(not Spar.isDown(b) and hb.Health == hb.MaxHealth, "Didn't get back up at full health")
check(b:GetAttribute("Spar") == true, "Getting up put the kit away")
now += Spar.SheatheLock + 1
check(Spar_(b, false).Ok and b:GetAttribute("Spar") == nil, "Couldn't put the kit away after the fight")
check(not CombatServer._canPvP(a, b), "Still in the spar with the kit away")

-- Requests that make no sense.
check(not Spar_(a, "yes").Ok, "A malformed request was accepted")
miner:SetAttribute("Outpost", nil)
check(not Spar_(miner, true).Ok and miner:GetAttribute("Spar") == nil, "Sparred outside the Outpost")
miner:SetAttribute("Outpost", true)
miner:SetAttribute("CombatSession", "PvP")
check(Spar_(miner, true).Message == "Finish your fight first.", "Sparred mid-fight")
miner:SetAttribute("CombatSession", nil)

-- The kit goes away by itself: leaving the Outpost, an Arena session, a
-- seat, a respawn.
check(a:GetAttribute("Spar") == true, "Lost the kit early")
a:SetAttribute("Outpost", nil)
check(a:GetAttribute("Spar") == nil, "Kept the kit out after leaving the Outpost")
a:SetAttribute("Outpost", true)
check(Spar_(a, true).Ok, "Couldn't take it out again")
a:SetAttribute("CombatSession", "PvP")
check(a:GetAttribute("Spar") == nil, "Kept the kit out in an Arena session")
a:SetAttribute("CombatSession", nil)
check(Spar_(a, true).Ok, "Couldn't take it out after the session")
ha.SeatPart = {}
now += 1
RunService.Heartbeat.Fire(0.1)
check(a:GetAttribute("Spar") == nil, "Kept the kit out in a seat")
ha.SeatPart = nil
check(Spar_(a, true).Ok, "Couldn't take it out again")
a.CharacterAdded.Fire(a.Character)
check(a:GetAttribute("Spar") == nil, "Kept the kit out through a respawn")
-- Knocked down then gone from the Outpost: healed, never left at 1 health.
check(Spar_(a, true).Ok and Spar_(b, true).Ok, "Couldn't spar again")
ha.Health = 1
SparServer._knockOut(a, ha, b)
check(Spar.isDown(a), "Not down")
a:SetAttribute("Outpost", nil)
check(ha.Health == ha.MaxHealth and a:GetAttribute("SparDown") == nil, "Left the Outpost knocked down at 1 health")

-- No jumping in a spar (Space is the dodge), as in any fight.
b:SetAttribute("Spar", true)
check(FightSpacing.inFight(b), "A spar isn't a fight for jumping")
b:SetAttribute("Spar", nil)
check(not FightSpacing.inFight(b), "Out of the spar, still in a fight")

print("PASS: " .. checks .. " spar checks (rules, who can hit whom, knock-downs, getting up, putting the kit away)")
