--[[
	Kaiju battles as an auto battler (the Kaiju Arena: Server.KaijuBattles,
	Server.KaijuBattleBrain). Every species has a role, and fights by it:

	  Tank      Carapace   holds the front and takes the hits. Its Taunting
	                       Roar makes the foes round it attack it instead.
	  Warrior   Bulwark    fights up close and hits hardest there.
	  Ranged    Razorback  stays back and shoots from range, and backs off
	                       from anyone who closes in. It never walks into
	                       the front line.
	  Assassin  Scythe     leaps over the front line at the start, onto
	                       their back row (a shooter first).
	  Breaker              (Shared.KaijuRoster: Triskull, Brightsteel,
	                       Dreadcrown) mid-line: goes for the foe with the
	                       toughest guard.
	  Warden               (Moonmoth) stays back with the shooters; its E
	                       and R shield and mend its team.

	The roster's kinds (Shared.KaijuRoster) each have three moves of their
	own; the first four share their role's.

	Each role has its own three moves (Kits), copied from the gem surges and
	renamed for kaiju (From): E when its mana is full (it fills as it hits
	and is hit), Q from level 5 every QEvery seconds, R from level 10 when
	its moment comes (When). They land as Server.KaijuAbilities casts them
	(Plan, its shape), in its element's colour; "Element" as a status is its
	element's own (Burn, Slow, Stun or Poison).

	Pure, for the server, the client and tests:
	  KaijuRoles.of(species) -> role id ("Tank", ...)
	  KaijuRoles.kit(species) -> { E, Q, R }   its moves
	  KaijuRoles.move(species, key, level) -> (id, awake)
	  KaijuRoles.Moves[id]   the moves, as the gem surges' catalog has them
	                         (Name, Description, IconSource) and their Plan
	  KaijuRoles.target(unit, foes, now) -> foe?   who it fights now
	  KaijuRoles.spot(unit, foe, allies, foes, bounds) -> (Vector3, boolean, boolean)
	                         where it goes, whether it can hit from there,
	                         and whether it's backing off
	  KaijuRoles.clamp(bounds, point) -> Vector3   inside the court
	  KaijuRoles.mana(role, attacked, lost) -> number   mana gained
	  KaijuRoles.wantsR(unit, foes, now) -> boolean   its R's moment

	A unit: { Role, Pos (Vector3), Health, MaxHealth, Target? (a unit),
	TauntBy? (a unit), TauntUntil?, CanBack? (false: a shooter that's just
	backed off stands its ground) } and foes/allies are lists of units.
	Bounds: { Center, Axis, Right, HalfLength, HalfWidth } (a court, Shared.
	KaijuPit, or the field between two players).
]]
local KaijuRoster = require(script.Parent.KaijuRoster)

local KaijuRoles = {}

-- Studs are a pet kaiju's (knee high). Reach: how near a melee one gets
-- to strike. Range and Keep: a shooter fires from up to Range, and backs
-- off from a foe nearer than Keep (if it has room). Windup: a blow's or a
-- shot's wind-up. Power: a blow's or a spine's share of its Damage, at
-- levels 1, 5 and 10 (KaijuRoles.power). Mana: gained per attack, and per
-- 1% of its health lost.
KaijuRoles.Roles = {
	Tank = {
		Id = "Tank",
		Name = "TANK",
		Blurb = "Holds the front and takes the hits. Its roar makes foes attack it.",
		Reach = 3.2,
		Windup = 0.4,
		Power = { 0.9, 0.7, 0.65 },
		Mana = { Attack = 10, Hurt = 1.2 },
		Front = true,
	},
	Warrior = {
		Id = "Warrior",
		Name = "WARRIOR",
		Blurb = "Fights up close and hits hardest there.",
		Reach = 3.2,
		Windup = 0.35,
		Power = { 1.05, 0.95, 0.85 },
		Mana = { Attack = 14, Hurt = 0.6 },
		Front = true,
	},
	Ranged = {
		Id = "Ranged",
		Name = "RANGED",
		Blurb = "Stays at the back and shoots from range. Keep it behind your front line.",
		Range = 15,
		Keep = 6,
		Windup = 0.4,
		Power = { 1.4, 1.6, 1.9 },
		Mana = { Attack = 12, Hurt = 0.5 },
		Front = false,
	},
	Assassin = {
		Id = "Assassin",
		Name = "ASSASSIN",
		Blurb = "Leaps over the front line onto their back row, a shooter first.",
		Reach = 2.8,
		Windup = 0.3,
		Power = { 0.8, 1.0, 1.1 },
		Mana = { Attack = 16, Hurt = 0.5 },
		Front = false,
		Opens = true, -- leaps at the start of a battle
	},
	Breaker = {
		Id = "Breaker",
		Name = "BREAKER",
		Blurb = "Goes for the foe with the toughest guard and breaks it.",
		Reach = 3.2,
		Windup = 0.35,
		Power = { 1.1, 1.0, 0.95 },
		Mana = { Attack = 14, Hurt = 0.6 },
		Front = true,
		Breaks = true, -- picks the toughest guard (KaijuRoles.target)
	},
	Warden = {
		Id = "Warden",
		Name = "WARDEN",
		Blurb = "Stays at the back and shields and mends its team.",
		Range = 14,
		Keep = 6,
		Windup = 0.4,
		Power = { 1.3, 1.5, 1.7 },
		Mana = { Attack = 12, Hurt = 1 },
		Front = false,
	},
}

KaijuRoles.Species = { Carapace = "Tank", Bulwark = "Warrior", Razorback = "Ranged", Scythe = "Assassin" }
for id, kind in KaijuRoster.Kinds do
	KaijuRoles.Species[id] = kind.Role
end
KaijuRoles.Order = { "Tank", "Warrior", "Ranged", "Assassin", "Breaker", "Warden" }

KaijuRoles.ManaMax = 100
KaijuRoles.MoveLevels = { Q = 5, E = 1, R = 10 }
KaijuRoles.QEvery = 8
KaijuRoles.FirstQ = 4 -- its Q this long into a battle
KaijuRoles.REvery = 14
-- A melee one keeps on the foe it's on unless another is this much nearer.
KaijuRoles.Stick = 5
-- A shooter backs off at most this often (it doesn't run for ever: in
-- between it stands and shoots).
KaijuRoles.BackEvery = 2.5

-- Each move's whole cast, as a share of its blows: Power times Mult
-- (Shared.Kaiju.abilityDamage). Its sizes (Radius, Length, Width,
-- Distance) are a player's, as every move's are: a kaiju's are its size
-- (Server.KaijuAbilities), a pet's a little under half.
KaijuRoles.Kits = {
	Tank = { E = "K_TauntingRoar", Q = "K_ShellSlam", R = "K_Fortress" },
	Warrior = { E = "K_Cleave", Q = "K_WarCry", R = "K_Earthshaker" },
	Ranged = { E = "K_SpineVolley", Q = "K_PiercingSpine", R = "K_Vault" },
	Assassin = { E = "K_ShadowLeap", Q = "K_Rend", R = "K_Vanish" },
}

KaijuRoles.Moves = {
	-- Tank ------------------------------------------------------------------------
	K_TauntingRoar = {
		Name = "Taunting Roar",
		Role = "Tank",
		Key = "E",
		From = "Resonance Echo",
		IconSource = "ResonanceEcho",
		Description = "A roar that makes every foe near it attack it for 3.5s, while it takes 35% less damage.",
		Plan = { Shape = "Taunt", Radius = 20, Duration = 3.5, Reduce = 0.35, Mult = 0.3, Power = 1 },
	},
	K_ShellSlam = {
		Name = "Shell Slam",
		Role = "Tank",
		Key = "Q",
		From = "Hydraulic Slam",
		IconSource = "HydraulicSlam",
		Description = "Slams its shell down: 110% damage to the foes round it, stunning them.",
		Plan = { Shape = "Nova", Radius = 12, Mult = 1.1, Status = "Stun", Power = 1.4 },
	},
	K_Fortress = {
		Name = "Fortress",
		Role = "Tank",
		Key = "R",
		From = "Cryo Shield",
		IconSource = "CryoShield",
		Description = "At half health: a shell that soaks 35% of its health for 5s, then bursts, slowing foes near it.",
		Plan = {
			Shape = "Shell",
			Absorb = 0.35,
			Duration = 5,
			Burst = { Radius = 14, Mult = 0.5, Status = "Slow" },
			Power = 1,
		},
		When = "Half",
	},
	-- Warrior ---------------------------------------------------------------------
	K_Cleave = {
		Name = "Cleave",
		Role = "Warrior",
		Key = "E",
		From = "Circuit Cleave",
		IconSource = "CircuitCleave",
		Description = "A wide sweep through its foe and anyone beside it: 160% damage.",
		Plan = { Shape = "Line", Length = 18, Width = 14, Mult = 1.6, Status = "Element", Power = 1.6 },
	},
	K_WarCry = {
		Name = "War Cry",
		Role = "Warrior",
		Key = "Q",
		From = "Overload",
		IconSource = "Overload",
		Description = "For 5s it hits 30% harder and 35% faster, and it heals 8% of its health.",
		Plan = { Shape = "Rally", Duration = 5, Damage = 1.3, Haste = 1.35, Heal = 0.08, Power = 0 },
	},
	K_Earthshaker = {
		Name = "Earthshaker",
		Role = "Warrior",
		Key = "R",
		From = "Tremor Slam",
		IconSource = "TremorSlam",
		Description = "Hard pressed or crowded: the ground under its foe breaks after a beat, 150% damage round it, stunning.",
		Plan = { Shape = "Blast", Radius = 16, Delay = 0.6, Mult = 1.5, Status = "Stun", Power = 1.4 },
		When = "Crowd",
	},
	-- Ranged ----------------------------------------------------------------------
	K_SpineVolley = {
		Name = "Spine Volley",
		Role = "Ranged",
		Key = "E",
		From = "Railstorm",
		IconSource = "Railstorm",
		Description = "Five spines rain on its foe and those near it: 130% damage in all, with its element's effect.",
		Plan = {
			Shape = "Storm",
			Radius = 14,
			Hits = 5,
			Mult = 1.3,
			Status = "Element",
			Show = "StormCall",
			Power = 1.8,
		},
	},
	K_PiercingSpine = {
		Name = "Piercing Spine",
		Role = "Ranged",
		Key = "Q",
		From = "Armor Piercer",
		IconSource = "ArmorPiercer",
		Description = "One spine through everyone in a line: 140% damage, leaving them Vulnerable.",
		Plan = { Shape = "Line", Length = 50, Width = 6, Mult = 1.4, Status = "Vulnerable", Power = 1.4 },
	},
	K_Vault = {
		Name = "Vault",
		Role = "Ranged",
		Key = "R",
		From = "Stim Dodge",
		IconSource = "StimDodge",
		Description = "A foe too close: it vaults back, leaving a patch that slows and hurts whoever followed.",
		Plan = { Shape = "Vault", Distance = 18, Radius = 11, Duration = 3, Mult = 0.6, Status = "Slow", Power = 1 },
		When = "Close",
	},
	-- Assassin --------------------------------------------------------------------
	K_ShadowLeap = {
		Name = "Shadow Leap",
		Role = "Assassin",
		Key = "E",
		From = "Thruster Leap",
		IconSource = "ThrusterLeap",
		Description = "Leaps behind its mark (their shooter first, else their weakest) and strikes it for 200%, leaving it Vulnerable.",
		Plan = { Shape = "Leap", Mult = 2, Status = "Vulnerable", Power = 1.4 },
	},
	K_Rend = {
		Name = "Rend",
		Role = "Assassin",
		Key = "Q",
		From = "Servo Flurry",
		IconSource = "ServoFlurry",
		Description = "Three quick rakes: 140% damage in all, the last with its element's effect.",
		Plan = { Shape = "Flurry", Hits = 3, Mult = 1.4, Status = "Element", Power = 1.4 },
	},
	K_Vanish = {
		Name = "Vanish",
		Role = "Assassin",
		Key = "R",
		From = "Null Prism",
		IconSource = "NullPrism",
		Description = "Low on health: it can't be hurt for 1.5s and reappears behind their weakest.",
		Plan = { Shape = "Vanish", Duration = 1.5, Pick = "Weakest", Mult = 0.8, Power = 1 },
		When = "Low",
	},
}
-- The roster's kinds' own moves, each its kind's role's.
for id, kind in KaijuRoster.Kinds do
	for _, moveId in kind.Kit do
		local move = KaijuRoster.Moves[moveId]
		move.Role, move.Kind = kind.Role, id
		KaijuRoles.Moves[moveId] = move
	end
end
for id, move in KaijuRoles.Moves do
	move.Id = id
end

-- What a status of "Element" means for each element.
KaijuRoles.ElementStatus = { Fire = "Burn", Frost = "Slow", Shock = "Stun", Poison = "Poison" }

function KaijuRoles.of(species: string?): string
	return KaijuRoles.Species[species or ""] or "Warrior"
end

-- Its moves: a roster kind's own, else its role's.
function KaijuRoles.kit(species: string?): { [string]: string }
	local kind = KaijuRoster.Kinds[species or ""]
	return if kind then kind.Kit else KaijuRoles.Kits[KaijuRoles.of(species)]
end

-- Its move on `key` (Q, E or R) and whether one of `level` has it yet.
function KaijuRoles.move(species: string?, key: string, level: number?): (string?, boolean)
	local id = KaijuRoles.kit(species)[key]
	return id, id ~= nil and (level or 1) >= (KaijuRoles.MoveLevels[key] or math.huge)
end

-- Mana from one attack (`attacked`) and from `lost` (a share, 0 to 1) of
-- its health gone.
function KaijuRoles.mana(role: string, attacked: boolean, lost: number): number
	local spec = KaijuRoles.Roles[role] or KaijuRoles.Roles.Warrior
	return (if attacked then spec.Mana.Attack else 0) + math.max(0, lost) * 100 * spec.Mana.Hurt
end

-- A blow's (or a spine's) share of its Damage in a battle: its role's
-- Power at level 1, at level 5 (its Q awake) and at level 10 (its R),
-- in between from one to the next. (A tank's and a warrior's Q and R
-- carry more of their fight than a shooter's or an assassin's, so their
-- blows' share falls as those wake and the others' rises.)
function KaijuRoles.power(role: string, level: number?): number
	local spec = KaijuRoles.Roles[role] or KaijuRoles.Roles.Warrior
	local power = spec.Power
	if type(power) ~= "table" then
		return power or 1
	end
	local at = { 1, KaijuRoles.MoveLevels.Q, KaijuRoles.MoveLevels.R }
	level = level or 1
	for i = 2, #at do
		if level <= at[i] then
			local t = math.clamp((level - at[i - 1]) / (at[i] - at[i - 1]), 0, 1)
			return power[i - 1] + (power[i] - power[i - 1]) * t
		end
	end
	return power[#at]
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distance(a, b): number
	return flat(a.Pos - b.Pos).Magnitude
end

local function nearest(unit, foes)
	local best, bestDistance = nil, math.huge
	for _, foe in foes do
		local d = distance(unit, foe)
		if d < bestDistance then
			best, bestDistance = foe, d
		end
	end
	return best, bestDistance
end

local function alive(foe, foes): boolean
	return foe ~= nil and table.find(foes, foe) ~= nil
end

-- Who `unit` fights now, of `foes` (those still up): its taunter while
-- it's taunted; else the one it's on while that still makes sense (an
-- assassin sees its mark through, a shooter keeps one in range, a melee
-- one keeps it unless another's well nearer); else, for an assassin, a
-- shooter of theirs (the nearest), then the weakest; for a shooter, the
-- weakest in range, then the nearest; for a breaker the toughest guard
-- (Guard: its kind's), the nearest of those; for the rest the nearest.
function KaijuRoles.target(unit, foes, now: number)
	if #foes == 0 then
		return nil
	end
	if unit.TauntBy and now < (unit.TauntUntil or 0) and alive(unit.TauntBy, foes) then
		return unit.TauntBy
	end
	local role = KaijuRoles.Roles[unit.Role] or KaijuRoles.Roles.Warrior
	local current = if alive(unit.Target, foes) then unit.Target else nil
	local close, closeDistance = nearest(unit, foes)
	if role.Id == "Assassin" then
		if current then
			return current
		end
		local shooter, shooterDistance = nil, math.huge
		for _, foe in foes do
			local d = distance(unit, foe)
			if foe.Role == "Ranged" and d < shooterDistance then
				shooter, shooterDistance = foe, d
			end
		end
		if shooter then
			return shooter
		end
		local weakest, least = nil, math.huge
		for _, foe in foes do
			if foe.Health < least then
				weakest, least = foe, foe.Health
			end
		end
		return weakest
	elseif role.Id == "Ranged" then
		if current and distance(unit, current) <= role.Range + 2 then
			return current
		end
		local weakest, least = nil, math.huge
		for _, foe in foes do
			if distance(unit, foe) <= role.Range and foe.Health < least then
				weakest, least = foe, foe.Health
			end
		end
		return weakest or close
	elseif role.Breaks then
		if current and distance(unit, current) <= closeDistance + KaijuRoles.Stick * 2 then
			return current
		end
		local best, bestGuard, bestDistance = nil, -1, math.huge
		for _, foe in foes do
			local guard, d = foe.Guard or 0, distance(unit, foe)
			if guard > bestGuard + 1e-6 or (math.abs(guard - bestGuard) <= 1e-6 and d < bestDistance) then
				best, bestGuard, bestDistance = foe, guard, d
			end
		end
		return best
	end
	if current and distance(unit, current) <= closeDistance + KaijuRoles.Stick then
		return current
	end
	return close
end

-- `point` brought inside `bounds` (Inset in from its rails), at its own
-- height. Without bounds, as it is.
KaijuRoles.Inset = 1.2
function KaijuRoles.clamp(bounds, point: Vector3, inset: number?): Vector3
	if not bounds then
		return point
	end
	local keep = inset or KaijuRoles.Inset
	local d = point - bounds.Center
	local across = math.clamp(d:Dot(bounds.Right), -bounds.HalfWidth + keep, bounds.HalfWidth - keep)
	local along = math.clamp(d:Dot(bounds.Axis), -bounds.HalfLength + keep, bounds.HalfLength - keep)
	local at = bounds.Center + bounds.Right * across + bounds.Axis * along
	return Vector3.new(at.X, point.Y, at.Z)
end

-- A push away from allies closer than `space` (so they don't stack).
local function apart(unit, allies, space: number): Vector3
	local push = Vector3.zero
	for i, other in allies do
		if other ~= unit then
			local away = flat(unit.Pos - other.Pos)
			local d = away.Magnitude
			if d < space then
				local dir = if d > 0.05 then away.Unit else Vector3.new(math.cos(i), 0, math.sin(i))
				push += dir * (space - d)
			end
		end
	end
	return push
end

-- Where `unit` goes to fight `foe`, and whether it can strike (or shoot)
-- from where it is. A melee one closes to its reach, on its own side of a
-- foe it shares (each ally on it a little further round); a shooter holds
-- its ground while its foe's in range, closes only to range when it isn't,
-- and backs away from a foe nearer than Keep while there's room behind it
-- (not again till BackEvery's passed: unit.CanBack). Always inside the
-- bounds, so it never walks into the rails.
function KaijuRoles.spot(unit, foe, allies, foes, bounds): (Vector3, boolean, boolean)
	local role = KaijuRoles.Roles[unit.Role] or KaijuRoles.Roles.Warrior
	local here = unit.Pos
	if not foe then
		return here, false
	end
	local toward = flat(foe.Pos - here)
	local d = toward.Magnitude
	local dir = if d > 0.05 then toward.Unit else Vector3.new(0, 0, 1)
	if role.Range then
		local close, closeDistance = nearest(unit, foes)
		if close and closeDistance < role.Keep and unit.CanBack ~= false then
			local away = flat(here - close.Pos)
			away = if away.Magnitude > 0.05 then away.Unit else -dir
			local back = KaijuRoles.clamp(bounds, here + away * 5)
			if flat(back - here).Magnitude >= 2 then
				return back, d <= role.Range, true
			end
			-- (Backed into the rails: along them instead, if it can.)
			local side = Vector3.new(-away.Z, 0, away.X)
			for _, sign in { 1, -1 } do
				local along = KaijuRoles.clamp(bounds, here + side * sign * 5)
				if flat(along - here).Magnitude >= 2 and flat(along - close.Pos).Magnitude > closeDistance then
					return along, d <= role.Range, true
				end
			end
		end
		if d <= role.Range then
			return KaijuRoles.clamp(bounds, here + apart(unit, allies, 2.5)), true
		end
		return KaijuRoles.clamp(bounds, foe.Pos - dir * (role.Range - 1) + apart(unit, allies, 2.5)), false
	end
	local reach = role.Reach
	if d <= reach then
		return KaijuRoles.clamp(bounds, here + apart(unit, allies, 2)), true
	end
	-- Its own side of the foe: the allies on it spread round it.
	local sharing, rank = 0, 0
	for _, other in allies do
		if other.Target == foe then
			sharing += 1
			if other == unit then
				rank = sharing
			end
		end
	end
	local from = -dir
	if sharing > 1 and rank > 0 then
		local spread = math.rad(55) * ((rank - 1) - (sharing - 1) / 2)
		local c, s = math.cos(spread), math.sin(spread)
		from = Vector3.new(from.X * c - from.Z * s, 0, from.X * s + from.Z * c)
	end
	return KaijuRoles.clamp(bounds, foe.Pos + from * reach * 0.8), false
end

-- Its R's moment: a tank or a warden at half health, a warrior or a
-- breaker hard pressed or with two foes on it, a shooter with a foe too
-- close, an assassin low.
function KaijuRoles.wantsR(unit, foes, now: number): boolean
	local share = unit.Health / math.max(1, unit.MaxHealth)
	local role = unit.Role
	if role == "Tank" or role == "Warden" then
		return share <= 0.5
	elseif role == "Warrior" or role == "Breaker" then
		local near = 0
		for _, foe in foes do
			if distance(unit, foe) <= 8 then
				near += 1
			end
		end
		return share <= 0.4 or near >= 2
	elseif role == "Ranged" then
		local _, d = nearest(unit, foes)
		return d < (KaijuRoles.Roles.Ranged.Keep - 1)
	elseif role == "Assassin" then
		return share <= 0.4
	end
	return false
end

-- Bounds for a field off a court (between two players): a court's size
-- round its middle.
function KaijuRoles.fieldBounds(field, halfLength: number, halfWidth: number)
	local axis = field.Axis
	return {
		Center = field.Center,
		Axis = axis,
		Right = Vector3.new(-axis.Z, 0, axis.X),
		HalfLength = halfLength,
		HalfWidth = halfWidth,
	}
end

return KaijuRoles
