--[[
	Ability balance: simulated duels through the real CombatServer.

	Two identically geared Warriors stand 5 studs apart and fight to the
	death. Each runs the same greedy script: the ability under test whenever
	it is ready and affordable (a Pneumatic Jab only into a cast, Stim Dodge
	only when hurt), otherwise a plain swing, holding swings back to save
	Stamina for a maneuver that's off cooldown. Each side reacts on a random
	75% of ticks, so timing varies like a person's. Nothing else differs, so
	the win rate measures the ability itself.

	  Surges     every surge against every other surge of the same tier
	             (one gem in Q, Rank I, Size/Clarity 5)
	  Maneuvers  every maneuver against every other maneuver

	Run with tools/balance_sim.py (it stitches in the production modules and
	the test doubles). Seeded, so a run repeats exactly. Not modelled:
	movement, dodging, guarding and aim; every attack is in reach.
]]
local FIGHTS = tonumber(SIM_FIGHTS) or 16 -- per pairing (half with each side first)
local HEALTH = 400
local DT = 0.1
local LIMIT = 90 -- seconds; a fight that runs out goes to the healthier side
local REACTION = 0.75 -- chance to act on a given tick: uneven, human-ish timing

-- A seeded generator in place of the test doubles' pinned math.random.
local seed = 12345
math.random = function(a, b)
	seed = (seed * 1103515245 + 12345) % 2147483648
	local r = seed / 2147483648
	if a and b then
		return a + math.floor(r * (b - a + 1))
	elseif a then
		return 1 + math.floor(r * a)
	end
	return r
end

local function learnAll(player)
	local progress = Tree.initialize(profiles[player])
	progress.XP = (Tree.UnlockPoints - Tree.StartingPoints) * Tree.XPPerPoint
	for _, id in Tree.Order.RigManeuvers do
		progress.Unlocked[id] = true
	end
	Tree.initialize(profiles[player])
end

local a, ha, ra, la = makePlayer(301, arena, nil)
local b, hb, rb, lb = makePlayer(302, arena + Vector3.new(0, 0, -5), nil)
learnAll(a)
learnAll(b)
la.Shield, lb.Shield = "ArmorProspectorShield1", "ArmorProspectorShield1"

local TIER_OF = {}
for element, list in Tech.Surges do
	for tier, id in list do
		TIER_OF[id] = { Element = element, Tier = tier }
	end
end
TIER_OF.EnergySiphon = { Element = "Frost", Tier = 2 }
TIER_OF.ResonanceEcho = { Element = "Shock", Tier = 3 }

local function gemFor(id)
	local info = TIER_OF[id]
	return {
		Id = "sim-" .. id,
		Element = info.Element,
		Tier = "Rare",
		SurgeTier = info.Tier,
		SurgeRank = 1,
		Surge = id,
		Size = 5,
		Clarity = 5,
		Cut = 0,
	}
end

local fighters = {
	{ Player = a, Humanoid = ha, Root = ra, Loadout = la },
	{ Player = b, Humanoid = hb, Root = rb, Loadout = lb },
}

-- One fighter's turn: its ability when ready, else a swing.
local function act(me, foe)
	local st = CombatServer._state(me.Player)
	if me.Surge then
		if CombatServer._technology(me.Player, nil, foe.Root.Position, "Q") then
			return
		end
	elseif me.Move then
		local id = me.Move
		local foeState = CombatServer._state(foe.Player)
		local wanted = if id == "PneumaticJab"
			then #foeState.Pending > 0 or foeState.Channel ~= nil
			elseif id == "StimDodge" then me.Humanoid.Health < HEALTH * 0.7
			else true
		if wanted and CombatServer._technology(me.Player, id, foe.Root.Position) then
			return
		end
	end
	-- Like a player, save Stamina for a maneuver that's off cooldown.
	local saving = me.Move ~= nil
		and now >= (st.TechCooldowns[me.Move] or 0)
		and st.Resources.Stamina < (Tech.Catalog[me.Move].Cost or 0)
		and (me.Move ~= "StimDodge" or me.Humanoid.Health < HEALTH * 0.7)
	if #st.Pending == 0 and not st.Channel and not saving then
		CombatServer._attack(me.Player, foe.Root.Position, false)
	end
end

local function fight(first, second)
	now += 30
	for _, f in fighters do
		CombatServer.reset(f.Player)
		f.Humanoid.MaxHealth, f.Humanoid.Health = HEALTH, HEALTH
		f.Loadout.Surge1Gem = if f.Surge then gemFor(f.Surge) else nil
	end
	local started = now
	while now - started < LIMIT do
		now += DT
		CombatServer._tick(DT)
		-- Human timing: each side reacts on most ticks, not all.
		if math.random() < REACTION then
			act(first, second)
		end
		if math.random() < REACTION then
			act(second, first)
		end
		if first.Humanoid.Health <= 0 or second.Humanoid.Health <= 0 then
			break
		end
	end
	local winner = if first.Humanoid.Health / HEALTH >= second.Humanoid.Health / HEALTH then first else second
	return winner, now - started
end

-- Every pick against every other in `group`; returns win rates and times.
local function roundRobin(group, set)
	local wins, games, seconds = {}, {}, {}
	for _, id in group do
		wins[id], games[id], seconds[id] = 0, 0, {}
	end
	for i = 1, #group do
		for j = i + 1, #group do
			for n = 1, FIGHTS do
				local x, y = fighters[1], fighters[2]
				set(x, group[i])
				set(y, group[j])
				local first, second = if n % 2 == 0 then x else y, if n % 2 == 0 then y else x
				local winner, took = fight(first, second)
				local won = if winner == x then group[i] else group[j]
				wins[won] += 1
				for _, id in { group[i], group[j] } do
					games[id] += 1
					table.insert(seconds[id], took)
				end
			end
		end
	end
	return wins, games, seconds
end

local function report(title, group, wins, games, seconds)
	print(title)
	local worst = 0
	for _, id in group do
		local rate = wins[id] / math.max(1, games[id])
		table.sort(seconds[id])
		local median = seconds[id][math.max(1, #seconds[id] // 2)] or 0
		local flag = if rate > 0.65 then "  << strong" elseif rate < 0.35 then "  << weak" else ""
		worst = math.max(worst, math.abs(rate - 0.5))
		print(
			string.format("  %-18s wins %5.1f%%  (%d fights, median %4.1fs)%s", id, rate * 100, games[id], median, flag)
		)
	end
	return worst
end

-- Probe: each listed ability alone against a plain swinger, over SIM_FIGHTS
-- fights (alternating who acts first): its casts and the average health
-- margin it wins by (negative: the plain swinger won). "None" is the
-- baseline. python tools/balance_sim.py 10 None,IonSpark,CryoStream
if SIM_PROBE then
	for _, id in string.split(SIM_PROBE, ",") do
		local x, y = fighters[1], fighters[2]
		x.Surge, x.Move = nil, nil
		if TIER_OF[id] then
			x.Surge = id
		elseif id ~= "None" then
			x.Move = id
		end
		y.Surge, y.Move = nil, nil
		local casts, margin, won = 0, 0, 0
		local original = CombatServer._technology
		CombatServer._technology = function(...)
			local ok = original(...)
			if ok and select(1, ...) == x.Player then
				casts += 1
			end
			return ok
		end
		for n = 1, FIGHTS do
			local first, second = if n % 2 == 0 then x else y, if n % 2 == 0 then y else x
			local winner = fight(first, second)
			margin += (x.Humanoid.Health - y.Humanoid.Health) / HEALTH
			won += if winner == x then 1 else 0
		end
		CombatServer._technology = original
		print(
			string.format(
				"%-16s casts/fight %5.1f  wins %3d%%  margin %+6.1f%% of health",
				id,
				casts / FIGHTS,
				math.floor(won / FIGHTS * 100 + 0.5),
				margin / FIGHTS * 100
			)
		)
	end
	return
end
local spread = {}
for tier = 1, 4 do
	local group = {}
	for _, element in { "Fire", "Frost", "Poison", "Shock" } do
		table.insert(group, Tech.Surges[element][tier])
	end
	if Tech.Resonance[tier] then
		table.insert(group, Tech.Resonance[tier])
	end
	local wins, games, seconds = roundRobin(group, function(f, id)
		f.Surge, f.Move = id, nil
	end)
	spread["Surges, tier " .. tier] =
		report(string.format("Surges, tier %d (%s):", tier, Tech.TierNames[tier]), group, wins, games, seconds)
end
local moves = table.clone(Tech.Order.RigManeuvers)
table.remove(moves, table.find(moves, "PneumaticJab")) -- (nothing to interrupt there; see below)
local wins, games, seconds = roundRobin(moves, function(f, id)
	f.Surge, f.Move = nil, id
end)
spread.Maneuvers = report("Maneuvers:", moves, wins, games, seconds)
-- Pneumatic Jab only matters against a caster, so it's measured there: a
-- jabber and a plain swinger each fight every wind-up surge.
print("Pneumatic Jab against casters (win rate; a plain swinger in the same fight):")
for _, caster in { "SolarFlare", "ChainLightning", "Supernova", "AbsoluteZero", "CryoStream", "Overload" } do
	local rates = {}
	for _, kit in { "PneumaticJab", "None" } do
		local won = 0
		for n = 1, FIGHTS do
			local x, y = fighters[1], fighters[2]
			x.Surge, x.Move = nil, if kit == "None" then nil else kit
			y.Surge, y.Move = caster, nil
			local first, second = if n % 2 == 0 then x else y, if n % 2 == 0 then y else x
			if fight(first, second) == x then
				won += 1
			end
		end
		rates[kit] = won / FIGHTS
	end
	print(
		string.format(
			"  vs %-15s with the jab %5.1f%%   without %5.1f%%",
			caster,
			rates.PneumaticJab * 100,
			rates.None * 100
		)
	)
end
print("Widest gap from an even 50% per group:")
for name, gap in spread do
	print(string.format("  %-16s %4.1f points", name, gap * 100))
end
