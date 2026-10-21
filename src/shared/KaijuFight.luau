--[[
	How a kaiju fights (pure, so it can be tested). Exactly as a duellist
	fights in the Arena: Shared.DuelistBrain decides every move and the
	server's KaijuFighter carries it out, shrunk to the kaiju's size and in
	its kind's own blows:

	             Light (combos)   Heavy (breaks a guard)   Guard
	  Bulwark    Claw Swipe       Ground Stomp             arms up
	  Razorback  Bite             Tail Lash                a low crouch
	  Carapace   Shell Snap       Shell Slam               tucked in its shell
	  Scythe     Blade Slash      Scissor Strike           blades crossed

	besides a quick counter after a blocked blow or into an opening (Punish,
	Riposte), a pounce from mid range (Lunge), a hop aside (Dodge), circling
	(Strafe), backing off hurt (Retreat), and its Gemsoul's E (Surge).

	A Razorback, the lightest of the three, fights best from range (its
	style's Ranged): a quick combo of bites up close, then it hops back and
	looses volleys of spines from a distance, circling, hopping back again
	when it's pressed, before it closes in for the next combo (rangedMove).

	Distances: the brain thinks in a duellist's studs (Brain.Reach); a
	kaiju's own are its reach at its size (KaijuFight.reach), so a distance
	is scaled by Brain.Reach / its reach on the way in, and back on the way
	out (its steps, hops and pounces).

	  KaijuFight.style(speciesId)            its kind's blows and timings
	  KaijuFight.reach(reach, scale)         its melee reach at its size, studs
	  KaijuFight.windup(style, kind)         a blow's wind-up, seconds
	  KaijuFight.blow(style, kind, hits)     a blow's share of its Damage
	  KaijuFight.surgeKind(plan)             how its E winds up: "Nova" or "Bolt"
	  KaijuFight.new(speciesId, body, reach, rate)   a fighter's state
	  KaijuFight.raiseGuard(fighter, now, seconds) / dropGuard(fighter, now)
	  KaijuFight.parries(body, heavy, now)   does its guard parry this blow?
	  KaijuFight.resolve(body, heavy, now)   a blow on a kaiju -> outcome, share
	  KaijuFight.read(fighter, now, ratio)   what a foe sees of a kaiju
	  KaijuFight.view(fighter, foe, now, distance, ratio)   the brain's View
	  KaijuFight.decide(fighter, view, roll) the brain's choice
	  KaijuFight.inArc(dir, toward, arc)     is a foe inside a blow's arc?
	  KaijuFight.rangedMove(fighter, distance, now)   a ranged fighter's
	                                         move out at range

	A body is where a kaiju's guard and stuns live (its Enemies record or
	its pet record): GuardUntil, GuardMult, GuardRaisedAt, ParrySpent,
	GuardBrokenUntil, DodgeUntil, BlockedAt, StunUntil, SlowUntil. Times are
	os.clock().
]]
local Brain = require(script.Parent.DuelistBrain)

local KaijuFight = {}

-- Names: each blow's (the combat log; a heavy's shows on the cast bar).
-- Windup: times the brain's (Brain.Windup). Heavy: a heavy's share of its
-- Damage. Combo: up to this many light blows in a row, each after the last
-- with ComboChance, ComboGap seconds apart. GuardMult: the share of a blow
-- that gets through its guard. Hop: how far it dodges (times a duellist's).
KaijuFight.Styles = {
	Bulwark = {
		Names = { Light = "Claw Swipe", Heavy = "Ground Stomp", Punish = "Counter Claw", Lunge = "Shoulder Ram" },
		Windup = 1.15,
		Heavy = 2,
		Combo = 2,
		ComboChance = 0.55,
		ComboGap = 0.55,
		GuardMult = 0.3,
		Hop = 0.9,
	},
	Razorback = {
		Names = { Light = "Bite", Heavy = "Tail Lash", Punish = "Snap Back", Lunge = "Pounce" },
		Windup = 0.8,
		Heavy = 1.6,
		Combo = 3,
		ComboChance = 0.75,
		ComboGap = 0.35,
		GuardMult = 0.4,
		Hop = 1.3,
		-- Up close it lands Combo blows (a combo or two), then hops back
		-- HopBack (a duellist's studs) and shoots: Volleys volleys, Every
		-- seconds apart, each Shots spines Gap apart after a Windup, each
		-- spine Mult of its Damage. It shoots from Keep[1] to Reach,
		-- circling inside Keep; pressed closer than Keep[1] it hops back
		-- again (at most every HopEvery seconds), or bites.
		Ranged = {
			Name = "Spine Volley",
			Combo = 2,
			HopBack = 12,
			HopEvery = 2.5,
			Keep = { 11, 17 },
			Reach = 26,
			Volleys = 3,
			Every = 1.4,
			Windup = 0.5,
			Shots = 3,
			Gap = 0.15,
			Mult = 0.5,
		},
	},
	Carapace = {
		Names = { Light = "Shell Snap", Heavy = "Shell Slam", Punish = "Spike Jab", Lunge = "Rolling Charge" },
		Windup = 1,
		Heavy = 1.8,
		Combo = 2,
		ComboChance = 0.6,
		ComboGap = 0.5,
		GuardMult = 0.15,
		Hop = 0.8,
	},
	Scythe = {
		Names = { Light = "Blade Slash", Heavy = "Scissor Strike", Punish = "Quick Cut", Lunge = "Mantis Leap" },
		Windup = 0.75,
		Heavy = 1.8,
		Combo = 3,
		ComboChance = 0.7,
		ComboGap = 0.3,
		GuardMult = 0.45,
		Hop = 1.4,
	},
}

-- A blow's share of its Damage (a heavy's is its style's); the third blow
-- of a combo lands harder.
KaijuFight.Blows = { Light = 1, Punish = 1, Lunge = 1.2 }
KaijuFight.Finisher = 1.3

KaijuFight.ParryWindow = 0.22 -- a light blow landing this soon after its guard goes up is parried
KaijuFight.ParryStagger = 0.45 -- and its attacker reels this long
KaijuFight.HighBlockEvery = 1.5 -- a raised guard parries at most this often
KaijuFight.GuardBreak = 0.9 -- a guard a heavy breaks can't go up again this soon
KaijuFight.BreakStagger = 0.35 -- and the heavy staggers it
KaijuFight.DodgeFor = 0.3 -- untouchable this long into a hop
KaijuFight.Recover = 0.35 -- open to a counter this long after its last blow
KaijuFight.HitRange = 1.5 -- a blow lands up to this far past its reach (the brain's studs)
KaijuFight.FirstSurge = 3 -- its E, this long into a fight
-- Against a swarm: a heavy sweeps through every foe in reach inside its
-- arc (Arc degrees, a Razorback's tail lash RazorArc), each of the others
-- taking Share of the blow; with Crowd or more foes in reach it swings a
-- heavy for a light Heavy of the time.
KaijuFight.Cleave = { Share = 0.6, Arc = 150, RazorArc = 220, Crowd = 3, Heavy = 0.6 }

local BLOWS = { Light = true, Heavy = true, Punish = true, Lunge = true }

function KaijuFight.style(speciesId: string?)
	return KaijuFight.Styles[speciesId or ""] or KaijuFight.Styles.Bulwark
end

-- Its melee reach in studs at its size (`reach` is its kind's at scale 1).
function KaijuFight.reach(reach: number, scale: number): number
	return reach * scale
end

function KaijuFight.windup(style, kind: string): number
	local base = Brain.Windup[kind] or Brain.Windup.Light
	return if BLOWS[kind] then base * style.Windup else base
end

-- A blow's share of its Damage: `hits` is where it falls in a combo.
function KaijuFight.blow(style, kind: string, hits: number?): number
	if kind == "Heavy" then
		return style.Heavy
	end
	return (KaijuFight.Blows[kind] or 1) * (if (hits or 1) >= 3 then KaijuFight.Finisher else 1)
end

-- How its E winds up: a ring round itself (time to get out of it), or
-- anything else aimed at its foe.
function KaijuFight.surgeKind(plan): string
	return if plan and plan.Shape == "Nova" then "Nova" else "Bolt"
end

-- A fighter: its kind's style, its body, its reach (studs) and how often
-- it attacks (its kind's Rate).
function KaijuFight.new(speciesId: string, body, reach: number, rate: number)
	return {
		Species = speciesId,
		Style = KaijuFight.style(speciesId),
		Body = body,
		Reach = reach,
		Rate = rate,
		Action = nil, -- { Kind, At, Hits } while winding up
		NextAttack = 0,
		NextSurge = 0, -- 0 until a fight starts
		NextDefense = 0,
		NextRetreat = 0,
		NextLunge = 0,
		NextHighBlock = 0,
		LastOffense = nil,
		SwingTimes = {}, -- when its last few blows came
		RecoverUntil = 0,
		RiposteFor = nil, -- the block it already answered
		FoeIdleSince = nil,
		FarSince = nil,
		RetreatUntil = nil,
		Weave = 1,
		NextWeave = 0,
	}
end

function KaijuFight.guarding(body, now: number): boolean
	return body.GuardUntil ~= nil and now < body.GuardUntil
end
local guarding = KaijuFight.guarding

-- Raises (or keeps up) its guard for `seconds`. Freshly raised, a light
-- blow landing at once is parried (at most every HighBlockEvery). Returns
-- whether it went up just now; a broken guard can't go up at all.
function KaijuFight.raiseGuard(f, now: number, seconds: number): boolean
	local body = f.Body
	local fresh = false
	if not guarding(body, now) then
		if now < (body.GuardBrokenUntil or 0) then
			return false
		end
		body.ParrySpent = false
		if now >= f.NextHighBlock then
			body.GuardRaisedAt = now
			f.NextHighBlock = now + KaijuFight.HighBlockEvery
		end
		fresh = true
	end
	body.GuardUntil = math.max(body.GuardUntil or 0, now + seconds)
	body.GuardMult = f.Style.GuardMult
	return fresh
end

function KaijuFight.dropGuard(f, now: number)
	if guarding(f.Body, now) then
		f.Body.GuardUntil = 0
	end
end

-- Does its guard parry this blow (a light one, landing just as it went
-- up)? Marks the parry spent.
function KaijuFight.parries(body, heavy: boolean?, now: number): boolean
	if
		heavy == false
		and guarding(body, now)
		and body.GuardRaisedAt
		and now - body.GuardRaisedAt <= KaijuFight.ParryWindow
		and not body.ParrySpent
	then
		body.ParrySpent = true
		body.BlockedAt = now
		return true
	end
	return false
end

-- A blow landing on a kaiju (`heavy` true or false for blows, nil for an
-- E): "Dodged" (mid-hop), "Parried", "Broken" (a heavy through its guard:
-- in full, and it reels), "Guarded" (GuardMult of it), or "Hit". Returns
-- the outcome and the share of the blow that lands.
function KaijuFight.resolve(body, heavy: boolean?, now: number): (string, number)
	if body.DodgeUntil and now < body.DodgeUntil then
		return "Dodged", 0
	end
	if not guarding(body, now) then
		return "Hit", 1
	end
	if heavy == true then
		body.GuardUntil = 0
		body.GuardBrokenUntil = now + KaijuFight.GuardBreak
		body.StunUntil = math.max(body.StunUntil or 0, now + KaijuFight.BreakStagger)
		return "Broken", 1
	end
	if KaijuFight.parries(body, heavy, now) then
		return "Parried", 0
	end
	if heavy ~= nil then
		body.BlockedAt = now -- a blow it can answer
	end
	return "Guarded", body.GuardMult or 0.3
end

-- What a foe sees of a kaiju this moment (`ratio` its health share): the
-- same things the brain reads off a player. Its light blows land straight
-- off a short wind-up, like a player's click; only a heavy shows as a charge.
function KaijuFight.read(f, now: number, ratio: number)
	local body = f.Body
	local action = f.Action
	local swings = 0
	for _, at in f.SwingTimes do
		if now - at <= 2.5 then
			swings += 1
		end
	end
	local last = f.SwingTimes[#f.SwingTimes]
	local guard = guarding(body, now)
	return {
		Charging = action ~= nil and action.Kind == "Heavy",
		Heavy = action ~= nil and action.Kind == "Heavy",
		LastSwing = last,
		Swings = swings,
		Casting = action ~= nil and (action.Kind == "Surge" or action.Kind == "Volley"),
		Blocking = guard,
		Recovering = action == nil and now < f.RecoverUntil,
		Vulnerable = now < (body.StunUntil or 0) or now < (body.SlowUntil or 0),
		Low = ratio < 0.3,
		Busy = action ~= nil or guard or (last ~= nil and now - last < 1),
		Ranged = f.Phase == "Range", -- (shooting from range: close in behind a guard)
	}
end

-- The brain's View of the fight, its foe read as above (or off a player,
-- by KaijuFighter): `distance` in studs, edge to edge.
function KaijuFight.view(f, foe, now: number, distance: number, ratio: number)
	local body = f.Body
	local d = distance * Brain.Reach / f.Reach
	if foe.Busy or not f.FoeIdleSince then
		f.FoeIdleSince = if foe.Busy then nil else now
	end
	-- How long its foe has kept out of reach: a pounce only closes a gap held.
	if d > Brain.Reach + 2 then
		f.FarSince = f.FarSince or now
	else
		f.FarSince = nil
	end
	return {
		Now = now,
		Distance = d,
		HealthRatio = ratio,
		Stunned = now < (body.StunUntil or 0),
		FoeCharging = foe.Charging,
		FoeHeavy = foe.Heavy,
		FoeAttacking = foe.LastSwing ~= nil and now - foe.LastSwing < 0.5,
		FoeAggressive = foe.Swings >= 2,
		FoeRanged = foe.Ranged == true,
		GuardBroken = now < (body.GuardBrokenUntil or 0),
		Guarding = guarding(body, now),
		JustBlocked = body.BlockedAt ~= nil and now - body.BlockedAt < 0.5 and f.RiposteFor ~= body.BlockedAt,
		FoeCasting = foe.Casting,
		FoeBlocking = foe.Blocking,
		FoeRecovering = foe.Recovering,
		FoeVulnerable = foe.Vulnerable,
		FoeLow = foe.Low,
		FoeIdle = f.FoeIdleSince ~= nil and now - f.FoeIdleSince >= Brain.IdleAfter,
		SinceOffense = now - (f.LastOffense or now),
		NextAttack = f.NextAttack,
		NextSurge = f.NextSurge,
		NextDefense = f.NextDefense,
		NextRetreat = f.NextRetreat,
		NextLunge = f.NextLunge,
		FarFor = now - (f.FarSince or now),
	}
end

-- Is a foe `toward` it (flat, from it) inside a blow of `arc` degrees
-- swung along `dir` (flat, unit)?
function KaijuFight.inArc(dir: Vector3, toward: Vector3, arc: number): boolean
	local flatTo = Vector3.new(toward.X, 0, toward.Z)
	if flatTo.Magnitude < 0.05 then
		return true
	end
	return dir:Dot(flatTo.Unit) >= math.cos(math.rad(math.min(arc, 360) / 2)) - 1e-6
end

-- A ranged fighter (its style's Ranged) out at range, its foe `distance`
-- off (the brain's studs): "Hop" back (pressed closer than Keep[1], its hop
-- ready), "Bite" (pressed into reach, its hop not ready), "Volley" (its
-- next one due, its foe within Keep[1] to Reach), "Close" (too far to
-- shoot), or "Keep" (circling in its band till the next volley).
function KaijuFight.rangedMove(f, distance: number, now: number): string
	local ranged = f.Style.Ranged
	if distance < ranged.Keep[1] then
		if now >= (f.NextHop or 0) then
			return "Hop"
		elseif distance <= Brain.Reach + KaijuFight.HitRange and now >= f.NextAttack then
			return "Bite"
		end
		return "Keep"
	end
	if distance <= ranged.Reach and now >= (f.NextVolley or 0) then
		return "Volley"
	end
	return if distance > ranged.Keep[2] then "Close" else "Keep"
end

-- The brain's choice (`roll` in [0, 1)). It reads a threat, then waits a
-- beat before it reacts to the next. Surrounded (view.Crowd foes in reach),
-- a light blow becomes a sweeping heavy more often than not.
function KaijuFight.decide(f, view, roll: number): string
	local choice = Brain.decide(view, roll)
	if choice == "Light" and (view.Crowd or 0) >= KaijuFight.Cleave.Crowd and (roll * 7.31) % 1 < KaijuFight.Cleave.Heavy then
		choice = "Heavy"
	end
	if
		(view.FoeCharging or view.FoeCasting or view.FoeAttacking)
		and view.Distance <= Brain.Reach + 4
		and view.Now >= f.NextDefense
	then
		f.NextDefense = view.Now + 0.45
	end
	return choice
end

return KaijuFight
