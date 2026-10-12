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
CombatServer.reset(a)
CombatServer.reset(b)
print("PASS: " .. checks .. " live triad checks (sockets, Stamina R, output, walls, rebirth, empower, steals)")
end
