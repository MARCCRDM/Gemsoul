-- Friendly sparring in the lobby (Shared.Spar, Server.SparServer) against
-- the real CombatServer: asking, answering, who can hit whom (partners
-- only), the knock-down instead of a death, getting back up, and the spar
-- ending for both when it should.
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- The rules ---------------------------------------------------------------------------------------

check(Spar.canHit(true, true, false, false, false, true), "Two sparring partners can't fight")
check(not Spar.canHit(true, true, false, false, false, false), "Two players sparring with others could fight")
check(not Spar.canHit(true, nil, false, false, false, true), "A miner (kit away) can be hit")
check(not Spar.canHit(nil, true, false, false, false, true), "A miner (kit away) can hit")
check(not Spar.canHit(true, true, false, true, false, true), "A knocked-down player can be hit")
check(not Spar.canHit(true, true, true, false, false, true), "A knocked-down player can hit")
check(not Spar.canHit(true, true, false, false, true, true), "A player can hit themselves")
local function fake(id, with, kit)
	return {
		UserId = id,
		GetAttribute = function(_, key)
			return if key == "Spar" then kit elseif key == "SparWith" then with else nil
		end,
	}
end
check(Spar.paired(fake(1, 2, true), fake(2, 1, true)), "Partners aren't paired")
check(not Spar.paired(fake(1, 2, true), fake(2, 3, true)), "A one-sided pair counts")
check(not Spar.paired(fake(1, 2, nil), fake(2, 1, true)), "A pair with a kit away counts")
local self_ = fake(1, 1, true)
check(not Spar.paired(self_, self_), "Paired with yourself")
check(Spar.partner(fake(1, 2, true)) == 2 and Spar.partner(fake(1, 2, nil)) == nil, "Wrong partner")

local ready = { Outpost = true, Alive = true, Seated = false }
check(Spar.startProblem(ready) == nil, "A free miner in the Outpost can't spar")
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
local function asking(changes)
	local ask = { Here = true, Name = "Bo", Mine = ready, Theirs = ready, Distance = 8 }
	for key, value in changes do
		ask[key] = value
	end
	return Spar.askProblem(ask)
end
check(asking({}) == nil, "A fair request was refused")
check(asking({ Here = false }) == "That player isn't here.", "Asked someone who isn't here")
check(asking({ Mine = { Outpost = false, Alive = true, Seated = false } }) ~= nil, "Asked from outside the Outpost")
check(asking({ MyPartner = "Al" }) == "You're already sparring with Al.", "Asked mid-spar")
check(asking({ TheirPartner = "Al" }) == "Bo is already sparring.", "Asked someone mid-spar")
check(
	asking({ Theirs = { Outpost = true, Alive = true, Seated = false, Busy = "MatchId" } })
		== "Bo can't spar right now.",
	"Asked someone in a match"
)
check(asking({ Distance = Spar.AskRange + 1 }) == "Get closer to Bo to ask.", "Asked from across the map")
check(asking({ Distance = false }) ~= nil, "Asked with no distance to go on")
check(asking({ Asked = true }) == "You've asked Bo already.", "Asked twice")
check(asking({ Wait = 3 }) ~= nil and asking({ Wait = -1 }) == nil, "The wait after a no is wrong")

check(Spar.stopWait({}, 50) == 0, "Free to stop untouched")
check(math.abs(Spar.stopWait({ Hurt = 49 }, 50) - (Spar.SheatheLock - 1)) < 1e-6, "Stopped straight after a hit")
check(Spar.stopWait({ Hurt = 40 }, 50) == 0, "Held long after the last hit")
check(Spar.stopWait({ Down = 52 }, 50) == 2, "Stopped while knocked down")

-- Knock-downs are the lobby's only: a miner or a sparring player in the
-- Outpost goes down, but not in a rival fight, a 1v1, a dungeon or an
-- expedition started from it (the Outpost flag still on).
local function at(attrs)
	return { GetAttribute = function(_, key) return attrs[key] end }
end
check(Spar.knocksDown(at({ Outpost = true })), "A miner in the lobby isn't knocked down")
check(Spar.knocksDown(at({ Outpost = true, Spar = true })), "A sparring player isn't knocked down")
for _, busy in { "CombatSession", "MatchId", "DungeonId", "Expedition" } do
	check(not Spar.knocksDown(at({ Outpost = true, [busy] = "x" })), "Knocked down mid-match (" .. busy .. ")")
	check(not Spar.knocksDown(at({ Outpost = true, Spar = true, [busy] = "x" })), "A spar's knock-down in a match (" .. busy .. ")")
	check(Spar.inMatch(at({ [busy] = "x" })), "Not in a match with " .. busy)
end
check(not Spar.knocksDown(at({})), "Knocked down outside the Outpost")

-- With the real CombatServer ----------------------------------------------------------------------

function Players:GetPlayerByUserId(id)
	for _, player in playerList do
		if player.UserId == id then
			return player
		end
	end
	return nil
end
local social, notes = {}, {}
Remotes.Social = {
	FireClient = function(_, player, ...)
		table.insert(social, { Player = player, ... })
	end,
}
Remotes.Notify = {
	FireClient = function(_, player, text)
		table.insert(notes, { Player = player, Text = text })
	end,
}
local function lastSocial(player)
	for i = #social, 1, -1 do
		if social[i].Player == player then
			return social[i]
		end
	end
	return nil
end
local function noted(player, text)
	for _, note in notes do
		if note.Player == player and note.Text:find(text, 1, true) then
			return true
		end
	end
	return false
end

local outpost = Vector3.new(0, 5, 7000)
local a, ha, ra = makePlayer(1, outpost, nil)
local b, hb, rb = makePlayer(2, outpost + Vector3.new(0, 0, -5), nil)
local c, hc, rc = makePlayer(3, outpost + Vector3.new(4, 0, -2), nil)
local d, hd, rd = makePlayer(4, outpost + Vector3.new(-4, 0, -2), nil)
for _, entry in { { a, ha }, { b, hb }, { c, hc }, { d, hd } } do
	local player, humanoid = entry[1], entry[2]
	-- (Lobby players: no Arena opt-in.)
	player:SetAttribute("PvPEnabled", false)
	player:SetAttribute("Outpost", true)
	player.DisplayName = "P" .. player.UserId
	player.Parent = Players
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
local Spar_, Ask, Respond = registered.Spar, registered.SparAsk, registered.SparRespond
check(Spar_ ~= nil and Ask ~= nil and Respond ~= nil, "Spar requests not registered")
local function tick()
	now += 0.3
	RunService.Heartbeat.Fire(0.3)
end
local function gap()
	now += Spar.AskGap + 0.1
end

-- Nobody fights without asking.
check(not CombatServer._canPvP(a, b), "Lobby players could fight without sparring")
local alone = Spar_(a, true)
check(not alone.Ok and alone.Message:find("press Z", 1, true), "1 alone didn't say how to ask")
check(a:GetAttribute("Spar") == nil, "The kit came out without anyone agreeing")

-- Asking.
local asked = Ask(a, b.UserId)
check(asked.Ok and asked.Message == "Asked P2 to spar.", "Couldn't ask")
local card = lastSocial(b)
check(
	card ~= nil and card[1] == "SparAsk" and card[2] == a.UserId and card[3] == "P1" and card[4] == Spar.AskSeconds,
	"The one asked got no card, or the wrong one"
)
check(a:GetAttribute("Spar") == nil and b:GetAttribute("Spar") == nil, "Asking alone started the spar")
check(not CombatServer._canPvP(a, b), "Could fight before an answer")
check(Ask(a, c.UserId).Message == "One moment.", "No gap between requests")
gap()
check(Ask(a, b.UserId).Message == "You've asked P2 already.", "Asked twice")
gap()
rc.Position = outpost + Vector3.new(0, 0, 200)
check(Ask(a, c.UserId).Message == "Get closer to P3 to ask.", "Asked from across the map")
rc.Position = outpost + Vector3.new(4, 0, -2)
gap()
check(Ask(a, a.UserId).Message == "That player isn't here.", "Asked yourself")
gap()
check(Ask(a, "P2").Message == "That player isn't here.", "A malformed request was accepted")
gap()
check(Ask(a, 999).Message == "That player isn't here.", "Asked someone not in the server")

-- A no.
check(not Respond(c, a.UserId, true).Ok, "Answered a request nobody made")
check(Respond(b, a.UserId, false).Ok, "Couldn't say no")
check(noted(a, "P2 said no to a spar."), "The asker never heard the no")
check(a:GetAttribute("Spar") == nil and b:GetAttribute("Spar") == nil, "A no started the spar")
check(not Respond(b, a.UserId, true).Ok, "Took back a no")
gap()
check(Ask(a, b.UserId).Message == "Give P2 a moment before asking again.", "Asked again straight after a no")
now += Spar.AskAgain
check(Ask(a, b.UserId).Ok, "Couldn't ask again after a while")

-- A yes.
local yes = Respond(b, a.UserId, true)
check(yes.Ok, "Couldn't accept: " .. tostring(yes.Message))
check(a:GetAttribute("Spar") == true and b:GetAttribute("Spar") == true, "Kits didn't come out")
check(a:GetAttribute("SparWith") == b.UserId and b:GetAttribute("SparWith") == a.UserId, "Not paired")
check(noted(a, "P2 accepted. Fight!"), "The asker never heard the yes")
check(CombatServer._canPvP(a, b) and CombatServer._canPvP(b, a), "Partners couldn't fight")
check(not CombatServer._canPvP(a, c) and not CombatServer._canPvP(c, a), "A miner was in the spar")
check(not Respond(b, a.UserId, true).Ok, "Accepted the same request twice")
-- Friends spar too: same party or team doesn't stop it.
a.Team, b.Team, a.Neutral, b.Neutral = "Blue", "Blue", false, false
check(CombatServer._canPvP(a, b), "Teammates couldn't spar")
a.Neutral, b.Neutral = true, true

-- Nobody joins a spar: not by asking, and not by sparring with someone else.
gap()
check(Ask(c, a.UserId).Message == "P1 is already sparring.", "Asked someone mid-spar")
gap()
check(Ask(a, c.UserId).Message == "You're already sparring with P2.", "Asked a second partner")
gap()
check(Ask(c, d.UserId).Ok and Respond(d, c.UserId, true).Ok, "A second pair couldn't spar")
check(CombatServer._canPvP(c, d), "The second pair couldn't fight")
for _, pair in { { a, c }, { a, d }, { b, c }, { b, d } } do
	check(
		not CombatServer._canPvP(pair[1], pair[2]) and not CombatServer._canPvP(pair[2], pair[1]),
		"Two spars crossed: P" .. pair[1].UserId .. " and P" .. pair[2].UserId
	)
end

-- A real blow lands on your partner, and only on them.
local function swing(attacker, target)
	CombatServer._input(attacker, "BeginAttack")
	now += 0.1
	CombatServer._input(attacker, "ReleaseAttack", target.Character.HumanoidRootPart.Position)
	now += 1
end
local before = hb.Health
swing(a, b)
check(hb.Health < before, "A sparring blow did no damage")
check(type(b:GetAttribute("SparHurt")) == "number", "A hit didn't hold the spar")
local refused = Spar_(b, false)
check(not refused.Ok and refused.Message:find("Still in the fight", 1, true), "Ended the spar mid-exchange")
local cBefore = hc.Health
swing(a, c)
check(hc.Health == cBefore, "A blow landed on someone else's spar")
local aBefore = ha.Health
swing(c, a)
check(ha.Health == aBefore, "Someone else's spar landed a blow")

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
aBefore = ha.Health
swing(b, a)
check(ha.Health == aBefore, "A downed player's swing landed")
check(not Spar_(b, false).Ok, "Ended the spar while down")
-- Up again: full health, still sparring.
SparServer._getUp(b, hb)
check(not Spar.isDown(b) and hb.Health == hb.MaxHealth, "Didn't get back up at full health")
check(b:GetAttribute("Spar") == true and Spar.paired(a, b), "Getting up ended the spar")

-- Ending it ends it for both.
now += Spar.SheatheLock + 1
check(Spar_(b, false).Ok, "Couldn't end the spar after the fight")
check(b:GetAttribute("Spar") == nil and a:GetAttribute("Spar") == nil, "The spar ended for one only")
check(a:GetAttribute("SparWith") == nil and b:GetAttribute("SparWith") == nil, "The pair outlived the spar")
check(noted(a, "P2 ended the spar."), "The partner never heard it end")
check(not CombatServer._canPvP(a, b), "Still in the spar with the kit away")
check(c:GetAttribute("Spar") == true and Spar.paired(c, d), "Ending one spar ended another")
check(Spar_(c, false).Ok and d:GetAttribute("Spar") == nil, "The second pair couldn't stop")

-- Asking each other is a yes from both.
gap()
check(Ask(a, b.UserId).Ok, "Couldn't ask")
gap()
check(Ask(b, a.UserId).Ok and Spar.paired(a, b), "Asking back didn't start the spar")
now += Spar.SheatheLock + 1
check(Spar_(a, false).Ok and b:GetAttribute("Spar") == nil, "Couldn't stop")

-- A request runs out: the asker hears, the answer is too late.
gap()
check(Ask(a, b.UserId).Ok, "Couldn't ask")
now += Spar.AskSeconds + 1
tick()
check(noted(a, "P2 didn't answer."), "The asker never heard it ran out")
check(not Respond(b, a.UserId, true).Ok and a:GetAttribute("Spar") == nil, "Accepted a request that ran out")
now += Spar.AskAgain

-- The asker spars with someone else first: the card comes down, and a late
-- yes does nothing.
gap()
check(Ask(a, b.UserId).Ok, "Couldn't ask")
gap()
check(Ask(c, a.UserId).Ok and Respond(a, c.UserId, true).Ok, "Couldn't take another spar")
local over = lastSocial(b)
check(over ~= nil and over[1] == "SparAskOver" and over[2] == a.UserId, "The other card stayed up")
local late = Respond(b, a.UserId, true)
check(not late.Ok and b:GetAttribute("Spar") == nil and Spar.paired(a, c), "A late yes broke into a spar")
now += Spar.SheatheLock + 1
check(Spar_(a, false).Ok, "Couldn't stop")

-- The asker gets busy (an Arena session): their request is withdrawn.
gap()
check(Ask(a, b.UserId).Ok, "Couldn't ask")
a:SetAttribute("CombatSession", "PvP")
over = lastSocial(b)
check(over ~= nil and over[1] == "SparAskOver", "A busy asker's card stayed up")
check(not Respond(b, a.UserId, true).Ok and b:GetAttribute("Spar") == nil, "Sparred with someone in a session")
a:SetAttribute("CombatSession", nil)
gap()
b:SetAttribute("MatchId", "m1")
check(Ask(a, b.UserId).Message == "P2 can't spar right now.", "Asked someone in a match")
b:SetAttribute("MatchId", nil)

-- Two people ask the same player: the one not picked hears, and their
-- request is gone.
gap()
check(Ask(a, c.UserId).Ok, "Couldn't ask")
gap()
check(Ask(d, c.UserId).Ok, "Two players couldn't ask the same one")
check(Respond(c, a.UserId, true).Ok and Spar.paired(a, c), "Couldn't pick one")
check(noted(d, "P3 is sparring with someone else."), "The other asker never heard")
check(not Respond(c, d.UserId, true).Ok and Spar.paired(a, c), "A second yes broke into the spar")
now += Spar.SheatheLock + 1
check(Spar_(a, false).Ok, "Couldn't stop")
-- A yes that can't start (they're in a seat): the asker hears.
gap()
check(Ask(a, b.UserId).Ok, "Couldn't ask")
hb.SeatPart = {}
local seated = Respond(b, a.UserId, true)
check(not seated.Ok and seated.Message == "Hop out of the machine first.", "Accepted from a seat")
check(noted(a, "P2 couldn't start the spar."), "The asker never heard the yes fell through")
check(a:GetAttribute("Spar") == nil and b:GetAttribute("Spar") == nil, "Sparred from a seat")
hb.SeatPart = nil

-- The spar ends for both whenever it stops making sense for either.
local function pair()
	gap()
	local asked_ = Ask(a, b.UserId)
	check(asked_.Ok, "Couldn't ask: " .. tostring(asked_.Message))
	local ok = Respond(b, a.UserId, true)
	check(ok.Ok and Spar.paired(a, b), "Couldn't pair: " .. tostring(ok.Message))
end
local function over_(why)
	check(a:GetAttribute("Spar") == nil and b:GetAttribute("Spar") == nil, "Still sparring after " .. why)
	check(a:GetAttribute("SparWith") == nil and b:GetAttribute("SparWith") == nil, "Still paired after " .. why)
end
pair()
a:SetAttribute("Outpost", nil)
over_("leaving the Outpost")
check(noted(b, "The spar with P1 is over."), "The partner never heard why")
a:SetAttribute("Outpost", true)
pair()
b:SetAttribute("CombatSession", "PvP")
over_("an Arena session")
b:SetAttribute("CombatSession", nil)
pair()
ha.SeatPart = {}
tick()
over_("a seat")
ha.SeatPart = nil
pair()
b.CharacterAdded.Fire(b.Character)
over_("a respawn")
pair()
rb.Position = outpost + Vector3.new(0, 0, -(Spar.MaxApart + 10))
tick()
over_("drifting apart")
check(noted(a, "drifted apart") and noted(b, "drifted apart"), "Nobody heard they drifted apart")
rb.Position = outpost + Vector3.new(0, 0, -5)
-- Knocked down, then the partner leaves the Outpost: healed, never left at 1 health.
pair()
hb.Health = 1
SparServer._knockOut(b, hb, a)
check(Spar.isDown(b), "Not down")
a:SetAttribute("Outpost", nil)
over_("the partner leaving while you're down")
check(hb.Health == hb.MaxHealth and b:GetAttribute("SparDown") == nil, "Left at 1 health after the spar ended")
local guards = #listeners
SparServer._getUp(b, hb)
check(#listeners == guards, "Got a fight guard after the spar had ended")
a:SetAttribute("Outpost", true)
-- Leaving the game.
pair()
for i, player in playerList do
	if player == b then
		table.remove(playerList, i)
		break
	end
end
Players.PlayerRemoving.Fire(b)
check(a:GetAttribute("Spar") == nil and a:GetAttribute("SparWith") == nil, "Kept sparring with someone who left")
check(noted(a, "P2 left the game"), "Never heard the partner left")
table.insert(playerList, b)
-- A request to someone who then leaves: nothing left behind.
gap()
check(Ask(a, c.UserId).Ok, "Couldn't ask")
Players.PlayerRemoving.Fire(c)
check(SparServer._asks[c] == nil, "Requests to someone who left were kept")

-- No jumping in a spar (Space is the dodge), as in any fight.
b:SetAttribute("Spar", true)
check(FightSpacing.inFight(b), "A spar isn't a fight for jumping")
b:SetAttribute("Spar", nil)
check(not FightSpacing.inFight(b), "Out of the spar, still in a fight")

-- Hunting: the kit out alone, against the Outpost's creatures (KaijuWilds).
local Hunt = registered.Hunt
check(Hunt ~= nil, "Hunt isn't a request")
for _, player in { a, b, c, d } do
	SparServer._stop(player)
end
check(not Hunt(a, "yes").Ok, "A malformed hunt request")
check(Hunt(a, true).Ok and a:GetAttribute("Hunt") == true and a:GetAttribute("Spar") == true, "No kit out to hunt")
check(Spar.hunting(a) and Spar.partner(a) == nil and Spar.active(a), "A hunter isn't hunting, alone")
check(Hunt(a, true).Ok, "Hunting twice failed")
tick()
check(Spar.hunting(a), "The hunt ended on its own (no partner)")
check(not CombatServer._canPvP(a, b) and not CombatServer._canPvP(b, a), "A hunter and a miner can fight")
check(Hunt(b, true).Ok and not CombatServer._canPvP(a, b), "Two hunters can fight each other")
SparServer._stop(b)
gap()
check(Ask(c, a.UserId).Message == "P1 is out hunting.", "Asked a hunter to spar")
gap()
check(Ask(a, c.UserId).Message == "Put your kit away first (1).", "A hunter asked to spar")
-- A creature's finishing blow knocks a hunter down, as in a spar.
local bug = { Root = { Position = ra.Position }, Kind = { Name = "Moon Bug" }, Element = "Fire", Model = nil }
ha.Health = 5
pcall(Enemies.hitPlayer, a, 500, "Fire", bug)
check(ha.Health >= 1 and Spar.isDown(a), "A creature's blow killed a hunter (or didn't land)")
-- Can't put the kit away mid-fight; can a moment later.
check(not Hunt(a, false).Ok, "Put the kit away while down")
now += Spar.DownSeconds + Spar.SheatheLock + 0.1
SparServer._getUp(a, ha)
check(ha.Health == ha.MaxHealth, "Not back up, whole")
check(Hunt(a, false).Ok and a:GetAttribute("Hunt") == nil and a:GetAttribute("Spar") == nil, "Couldn't put it away")
-- A rift's critter catching a miner (kit away) out in the Outpost: down,
-- then up again whole, with a moment's guard.
now += Spar.SheatheLock + 1
ha.Health = 5
pcall(Enemies.hitPlayer, a, 500, "Fire", bug)
check(ha.Health >= 1 and Spar.isDown(a), "A critter's blow killed a miner (or didn't land)")
local minerGuards = #listeners
SparServer._getUp(a, ha, true)
check(not Spar.isDown(a) and ha.Health == ha.MaxHealth, "A downed miner didn't get up whole")
check(#listeners == minerGuards + 1, "A downed miner got up with no guard")
-- The hunt ends by itself when hunting stops making sense (a seat, leaving).
check(Hunt(a, true).Ok, "Couldn't hunt again")
ha.SeatPart = {}
tick()
check(a:GetAttribute("Hunt") == nil and a:GetAttribute("Spar") == nil, "Hunted from a seat")
ha.SeatPart = nil
check(Hunt(a, true).Ok, "Couldn't hunt again")
a:SetAttribute("Outpost", nil)
check(a:GetAttribute("Hunt") == nil, "Hunted outside the Outpost")
check(not Hunt(a, true).Ok, "Hunted from outside the Outpost")
a:SetAttribute("Outpost", true)
-- Sparring, then asked to hunt: no.
pair()
check(Hunt(a, true).Message == "Finish your spar first.", "Hunted mid-spar")
-- "Spar", false puts a hunter's kit away too.
SparServer._stop(a)
check(Hunt(a, true).Ok, "Couldn't hunt")
now += Spar.SheatheLock + 1
check(Spar_(a, false).Ok and a:GetAttribute("Hunt") == nil, "1 didn't end the hunt")

print(
	"PASS: "
		.. checks
		.. " spar checks (asking, answering, partners only, knock-downs, getting up, ending it for both, hunting)"
)
