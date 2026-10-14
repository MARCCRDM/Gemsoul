-- The Q / E / R triad in a live fight (CombatServer + TriadServer): Q comes
-- from the sword's gem, E from the core socket, R from the shield and pays
-- Stamina. Run inside run_combat.py, after the classic suites.
do
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function close(a, b)
	return math.abs(a - b) < 1e-4
end
local a, ha, ra, loadout = makePlayer(901, arena + Vector3.new(4, 0, 4), nil)
local b, hb, rb = makePlayer(902, arena + Vector3.new(4, 0, -1), nil)
-- Keep everyone else out of reach.
for _, other in playerList do
	if other ~= a and other ~= b and other.Character then
		other.Character.HumanoidRootPart.Position = Vector3.new(20000, 0, 20000)
	end
end
local function gem(element, tier, traits)
	return { Id = "T" .. element .. tier, Element = element, Tier = tier, Size = 1, Clarity = 1, Cut = 1, Traits = traits }
end
local function fresh()
	now += 30
	CombatServer.reset(a)
	CombatServer.reset(b)
	ha.Health, hb.Health = 1000, 1000
	loadout.WeaponGem, loadout.ShieldGem, loadout.Surge1Gem, loadout.Surge2Gem, loadout.Surge3Gem = nil, nil, nil, nil, nil
	local st = CombatServer._state(a)
	st.Resources.Charge, st.Resources.Stamina = 100, 100
	return st, CombatServer._state(b)
end
local function settle(seconds)
	local step = 0.05
	for _ = 1, math.ceil(seconds / step) do
		now += step
		CombatServer._tick(step)
	end
end
local function cast(key)
	return CombatServer._technology(a, nil, rb.Position, key)
end

-- Q fires the sword gem's Offense; rarity sets its output.
local function crescent(tier)
	local st = fresh()
	loadout.WeaponGem = gem("Fire", tier, { Offense = "Q_FurnaceCrescent", Ability = "E_EmberLance", Defense = "R_HeatShield" })
	check(cast("Q"), "Q (Furnace Crescent) was rejected")
	settle(0.5)
	return 1000 - hb.Health, st
end
local common, st = crescent("Common")
check(common > 0, "Furnace Crescent did no damage")
check(st.Resources.Charge == 100 - Tech.Catalog.Q_FurnaceCrescent.Cost, "Q must pay its Charge")
local rare = crescent("Rare")
check(close(rare / common, 0.8 / 0.6), "Rarity sets output (Rare 80% vs Common 60%)")
local _, burning = fresh()
loadout.WeaponGem = gem("Fire", "Rare", { Offense = "Q_FurnaceCrescent" })
cast("Q")
settle(0.5)
check(next(burning.Dots) ~= nil, "Furnace Crescent sets its target burning")

-- R pays Stamina, not Charge, and goes up while you guard.
local st = fresh()
loadout.ShieldGem = gem("Fire", "Legendary", { Offense = "Q_CinderCleave", Ability = "E_HeatHaze", Defense = "R_HeatShield" })
st.Resources.Charge = 0
check(CombatServer._block(a, true, rb.Position), "Could not raise the guard")
check(cast("R"), "R must work at 0 Charge, guard raised")
check(close(st.Resources.Stamina, 100 - 20), "R pays its Stamina")
settle(0.4)
check(close(st.Shield, 40), "Heat Shield absorbs 40 at Legendary")

-- Frozen Wall stops every frontal blow.
st = fresh()
loadout.ShieldGem = gem("Frost", "Rare", { Defense = "R_FrozenWall" })
check(cast("R"), "Frozen Wall was rejected")
settle(0.4)
CombatServer._state(b).NextAttack = 0
CombatServer._attack(b, ra.Position, false)
check(ha.Health == 1000, "A frontal swing got through the Frozen Wall")
check(not CombatServer._attack(a, rb.Position, false), "You can't swing while the wall stands")

-- Phoenix Mantle: a fall under 20% becomes a rebirth, once.
st = fresh()
loadout.ShieldGem = gem("Fire", "Legendary", { Defense = "R_PhoenixMantle" })
check(cast("R"), "Phoenix Mantle was rejected")
settle(0.4)
ha.Health = 300
CombatServer.hurt(a, 5000, "Fire", nil)
check(ha.Health > 0, "Phoenix Mantle didn't save you")
settle(0.1)
check(close(ha.Health, 200 + 250), "A rebirth stops at 20% and heals 25%")
CombatServer.hurt(a, 5000, "Fire", nil)
check(ha.Health == 0, "Phoenix Mantle saved you twice")
ha.Health = 1000

-- Empower (Cinder Cleave): the next swings burn.
st = fresh()
loadout.WeaponGem = gem("Fire", "Rare", { Offense = "Q_CinderCleave" })
check(cast("Q"), "Cinder Cleave was rejected")
settle(0.4)
check(st.Triad.Empower and st.Triad.Empower.Left == 3, "Cinder Cleave empowers 3 swings")
st.NextAttack, st.NextTech = 0, 0
CombatServer._attack(a, rb.Position, false)
check(st.Triad.Empower.Left == 2, "A landed swing spends one empowered swing")
check(next(CombatServer._state(b).Dots) ~= nil, "An empowered swing ignites")

-- Steals: Sapping Edge drains Stamina at 60% in PvP, never below 15.
local _, victim = fresh()
st = CombatServer._state(a)
loadout.WeaponGem = gem("Poison", "Legendary", { Offense = "Q_SappingEdge" })
cast("Q")
settle(0.4)
victim.Resources.Stamina = 100
st.Resources.Stamina = 50
st.NextAttack = 0
CombatServer._attack(a, rb.Position, false)
check(close(victim.Resources.Stamina, 100 - 8 * 0.6), "Sapping Edge steals 8 Stamina (60% in PvP)")
victim.Resources.Stamina = 17
st.NextAttack = 0
CombatServer._attack(a, rb.Position, false)
check(victim.Resources.Stamina >= 15, "A drain never takes Stamina below 15")

-- Overcharge Strike spends every point of Charge.
st = fresh()
loadout.WeaponGem = gem("Shock", "Legendary", { Offense = "Q_OverchargeStrike" })
check(cast("Q"), "Overcharge Strike was rejected")
check(st.Resources.Charge == 0, "Overcharge Strike spends all your Charge")
settle(0.8)
check(hb.Health < 1000, "Overcharge Strike missed")

-- E fires the core gem's Ability; an Aura is on while E is ready.
st = fresh()
loadout.Surge2Gem = gem("Shock", "Legendary", { Ability = "E_Overload" })
check(TriadServer.chargeGain(a, CombatServer.kitFor(loadout, {}), st, now) > 1.2, "Overload adds Charge gain while ready")
check(cast("E"), "Overload was rejected")
check(TriadServer.chargeGain(a, CombatServer.kitFor(loadout, {}), st, now) == 1, "An Aura pauses while E recharges")

-- Old surge sockets are archived: Q and R ignore Surge1/Surge3.
st = fresh()
loadout.Surge1Gem = { Id = "old", Element = "Fire", Tier = "Legendary", Surge = "EmberLance" }
check(not cast("Q"), "Q must not fire the archived Surge1 gem")

-- Every move, at Common and Legendary (with its Flourish), goes off cleanly
-- and leaves nothing behind once its effects run out.
for _, id in GemTraits.all() do
	for _, tier in { "Common", "Legendary" } do
		st = fresh()
		local move = GemTraits.Moves[id]
		local traits = { [move.Lane] = id }
		local g = gem(GemTraits.Index[id].Element, tier, traits)
		local key = move.Key
		loadout[GemTraits.Sockets[key] .. "Gem"] = g
		-- A few blows on each side so poisons, chills and marks have something to work on.
		CombatServer._state(b).NextAttack = 0
		check(cast(key), id .. " (" .. tier .. ") was rejected")
		for _ = 1, 8 do
			settle(0.25)
			st.NextAttack = 0
			CombatServer._attack(a, rb.Position, false)
			CombatServer._state(b).NextAttack = 0
			CombatServer._attack(b, ra.Position, false)
			if move.PerSecond and st.Channel then
				CombatServer._technology(a, nil, rb.Position, key)
			end
		end
		settle(8)
		ha.Health, hb.Health = 1000, 1000
		ra.Position, rb.Position = arena + Vector3.new(4, 0, 4), arena + Vector3.new(4, 0, -1)
	end
end
-- The showcase defenses: each one puts something into the fight.
local function defense(element, id)
	local st = fresh()
	loadout.ShieldGem = gem(element, "Rare", { Defense = id })
	ra.Position = arena + Vector3.new(4, 0, 4)
	rb.Position = arena + Vector3.new(4, 0, -1)
	return st, CombatServer._state(b)
end
-- Ice Pillar: up on the ice, swords can't reach you; it shatters into a slow.
local st2, foe = defense("Frost", "R_IcePillar")
check(cast("R"), "Ice Pillar was rejected")
settle(0.4)
check(st2.Triad.Pillar ~= nil, "Ice Pillar didn't rise")
foe.NextAttack = 0
CombatServer._attack(b, ra.Position, false)
check(ha.Health == 1000, "A sword reached you on the Ice Pillar")
settle(3) -- (2.5s from when the cast lands)
check(st2.Triad.Pillar == nil, "The Ice Pillar didn't shatter")
check((foe.SlowUntil or 0) > now and (foe.Slow or 0) > 0, "The shatter didn't slow the foe")
-- Ring of Fire: crossing the ring burns.
st2, foe = defense("Fire", "R_RingOfFire")
rb.Position = ra.Position + Vector3.new(0, 0, -7)
check(cast("R"), "Ring of Fire was rejected")
settle(0.5)
check(next(foe.Dots) ~= nil, "Crossing the Ring of Fire didn't burn")
-- Tesla Fence: crossing it stuns.
st2, foe = defense("Shock", "R_TeslaFence")
check(cast("R"), "Tesla Fence was rejected")
settle(0.5)
check((foe.StunUntil or 0) > now, "Crossing the Tesla Fence didn't stun")
-- Spore Wall: crossing it poisons.
st2, foe = defense("Poison", "R_SporeWall")
check(cast("R"), "Spore Wall was rejected")
settle(0.5)
check(foe.Triad and next(foe.Triad.Poisons or {}) ~= nil, "Crossing the Spore Wall didn't poison")
-- Acid Slick: standing on it slows.
st2, foe = defense("Poison", "R_AcidSlick")
check(cast("R"), "Acid Slick was rejected")
settle(0.6)
check((foe.SlowUntil or 0) > now and (foe.Slow or 0) > 0, "The Acid Slick didn't slow")
-- Hologram Decoy: the hologram bursts and stuns.
st2, foe = defense("Shock", "R_HoloDecoy")
check(cast("R"), "Hologram Decoy was rejected")
settle(3.4)
check(hb.Health < 1000, "The decoy's burst did no damage")
check((foe.StunUntil or 0) > now - 1, "The decoy's burst didn't stun")

-- The intro moves: each does what it says, against a single foe.
local function sent(kind, to)
	local n = 0
	for _, message in messages do
		if message[1] == kind and (to == nil or message.Player == to) then
			n += 1
		end
	end
	return n
end
local function shows(name)
	local n = 0
	for _, message in messages do
		if message[1] == "TriadShow" and message[3] == name then
			n += 1
		end
	end
	return n
end
local function intro(element, lane, id, tier)
	local st = fresh()
	table.clear(messages)
	ra.Position = arena + Vector3.new(4, 0, 4)
	rb.Position = arena + Vector3.new(4, 0, -1)
	local key = if lane == "Offense" then "Q" else "E"
	loadout[GemTraits.Sockets[key] .. "Gem"] = gem(element, tier or "Rare", { [lane] = id })
	check(cast(key), id .. " was rejected")
	return st, CombatServer._state(b)
end
local function zoneOf(st, kind)
	for _, zone in st.Triad and st.Triad.Zones or {} do
		if zone.Kind == kind then
			return zone
		end
	end
	return nil
end
-- Meteor Leap: you leap, crash down on them, they're thrown back and the crater burns.
local st3, foe = intro("Fire", "Offense", "Q_MeteorLeap")
check(st3.DodgeMove and st3.DodgeMove.Kind == "Leap", "Meteor Leap didn't leap")
check(shows("MeteorLeapJump") == 1, "The leap has no look")
settle(0.6)
check(hb.Health < 1000, "Meteor Leap's crash missed")
check(sent("Blasted", b) > 0, "Meteor Leap didn't throw the foe back")
check(next(foe.Dots) ~= nil, "Meteor Leap didn't set the foe burning")
check(zoneOf(st3, "Crater") ~= nil and shows("Crater") == 1, "Meteor Leap left no crater")
check(shows("MeteorLeap") == 1, "The crash has no look")
-- Flame Tornado: rolls through them, scorches them again and again, drags them along, bursts.
st3, foe = intro("Fire", "Ability", "E_FlameTornado")
settle(0.6)
check(zoneOf(st3, "Vortex") ~= nil and shows("FlameTornado") == 1, "Flame Tornado didn't spin up")
local before = hb.Health
settle(1)
check(hb.Health < before, "The tornado didn't scorch the foe inside it")
check(sent("Shoved", b) >= 2, "The tornado didn't drag the foe along")
settle(1.6)
check(shows("VortexEnd") == 1, "The tornado didn't burst at the end")
check(zoneOf(st3, "Vortex") == nil, "The tornado outlived its run")
-- Frost Chakram: out and back, a hit and a Chill each way.
st3, foe = intro("Frost", "Offense", "Q_FrostChakram")
settle(0.35)
check(zoneOf(st3, "Disc") ~= nil and shows("FrostChakram") == 1, "Frost Chakram wasn't thrown")
local hits = 0
local last = hb.Health
for _ = 1, 30 do
	settle(0.05)
	if hb.Health < last then
		hits += 1
		last = hb.Health
	end
end
check(hits == 2, "Frost Chakram should hit going out and coming back, hit " .. hits)
check(foe.Triad and foe.Triad.Chill == 2, "Each chakram hit Chills")
-- Hailstorm: ticks on everyone inside; two seconds in, they freeze.
st3, foe = intro("Frost", "Ability", "E_Hailstorm")
settle(0.65)
check(zoneOf(st3, "Hail") ~= nil and shows("Hailstorm") == 1, "Hailstorm didn't start")
settle(2)
check(hb.Health < 1000, "The hail did no damage")
check(foe.StunUntil > now and foe.StunKind == "Frozen", "Two seconds of hail didn't freeze the foe")
-- Thunder Dash: through them as lightning: a hit and a stun, a crackling trail.
st3, foe = intro("Shock", "Offense", "Q_ThunderDash")
check(st3.DodgeMove ~= nil and shows("ThunderDash") == 1, "Thunder Dash didn't dash")
settle(0.25)
check(hb.Health < 1000, "Thunder Dash missed the foe it passed through")
check(foe.StunUntil > now - 0.3, "Thunder Dash didn't stun")
-- Skybreaker: a bolt from the sky: a big hit and a stun.
st3, foe = intro("Shock", "Offense", "Q_Skybreaker")
settle(0.6)
check(hb.Health < 1000 and foe.StunUntil > now, "Skybreaker didn't strike and stun")
check(shows("Skybreaker") == 1, "Skybreaker has no look")
-- Storm Call: 5 warned bolts hunting the foe; the last stuns.
st3, foe = intro("Shock", "Ability", "E_StormCall")
settle(0.55)
check(zoneOf(st3, "Storm") ~= nil and shows("StormCall") == 1, "Storm Call didn't gather")
settle(2.8)
check(shows("StormWarn") == 5 and shows("StormBolt") == 5, "Storm Call should warn and strike 5 times")
check(hb.Health < 1000, "The storm's bolts missed a foe standing still")
check(foe.StunUntil > now - 1, "The last bolt didn't stun")
-- Ion Cannon: pierces and blows them back.
st3, foe = intro("Shock", "Ability", "E_IonCannon")
settle(1)
check(hb.Health < 1000 and sent("Blasted", b) > 0, "The Ion Cannon didn't hit and blow back")
check(shows("IonCannon") == 1, "The Ion Cannon has no look")
-- Viper Lash: hits, poisons, slows and drags them in.
st3, foe = intro("Poison", "Offense", "Q_ViperLash")
settle(0.45)
check(hb.Health < 1000, "Viper Lash missed")
check(sent("Shoved", b) == 1, "Viper Lash didn't drag the foe in")
check(foe.Triad and next(foe.Triad.Poisons or {}) ~= nil and (foe.Slow or 0) > 0, "Viper Lash didn't poison and slow")
-- Toxic Flask: flies, then bursts where it was aimed and leaves a slowing pool.
st3, foe = intro("Poison", "Offense", "Q_ToxicFlask")
settle(0.5)
check(shows("ToxicFlaskThrow") == 1, "The flask wasn't thrown")
check(hb.Health == 1000, "The flask hit before it landed")
settle(0.45)
check(hb.Health < 1000, "The flask's burst missed")
check(zoneOf(st3, "Puddle") ~= nil and shows("Puddle") == 1, "The flask left no pool")
settle(0.6)
check((foe.Slow or 0) > 0, "The pool didn't slow")
-- Toxic Tide: hits once, poisons, makes them take more, carries them along.
st3, foe = intro("Poison", "Ability", "E_ToxicTide")
settle(0.6)
check(zoneOf(st3, "Wave") ~= nil and shows("ToxicTide") == 1, "Toxic Tide didn't roll out")
settle(1.3)
local tide = 1000 - hb.Health
check(tide > 0 and sent("Blasted", b) == 1, "The wave should hit and carry the foe once")
check(foe.CC.Debuffs.Vulnerable ~= nil, "The wave didn't leave them Vulnerable")
-- Maneater: snaps shut on them: a hit, held in place, poisoned.
st3, foe = intro("Poison", "Ability", "E_Maneater")
settle(0.8)
check(hb.Health < 1000 and shows("Maneater") == 1, "Maneater didn't bite")
check(foe.Triad and (foe.Triad.RootUntil or 0) > now and next(foe.Triad.Poisons or {}) ~= nil, "Maneater didn't hold and poison")

CombatServer.reset(a)
CombatServer.reset(b)
print("PASS: " .. checks .. " live triad checks (sockets, Stamina R, output, walls, rebirth, empower, steals, showcase defenses, the 12 intro moves)")
end
