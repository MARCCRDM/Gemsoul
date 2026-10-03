-- Universal Warrior controls and deterministic rules shared by HUD and server.
local ArmorFamilies = require(script.Parent.ArmorFamilies)
local Actions = {}
Actions.Order = { "Basic", "Heavy", "Dodge", "Block" }
Actions.Base = {
	Basic = { Name = "Attack", Damage = 1, SwordCooldown = 0.65, PistolCooldown = 0.45 },
	Heavy = {
		Name = "Heavy",
		Damage = 1.8,
		PvPDamage = 1.5,
		Cooldown = 1.2,
		Charge = 0.45,
		Knockback = 12,
		BreakSeconds = 0.8,
	},
	-- Double-tap Space: a long roll.
	Dodge = { Name = "Dodge", Cooldown = 3, Distance = 15, Duration = 0.25, Invincible = 0.5, PvPInvincible = 0.3 },
	-- Single tap: a quick hop to the side, cheap and fast but a short dodge window.
	Hop = {
		Name = "Hop",
		Cooldown = 0.6,
		Distance = 7,
		Duration = 0.18,
		Lift = 16,
		Invincible = 0.28,
		PvPInvincible = 0.2,
		Cost = 8,
	},
	Block = { Name = "Block", Reduction = 0.5, PvPReduction = 0.4, Arc = 120 },
}
--[[
	Stamina, Elder Scrolls style: every swing and every blow you take on your
	guard costs Stamina, and it only refills once you ease off.

	A light swing costs 0.4 Stamina per point of the weapon's damage, so
	heavier blades tire you faster (Attack.StaminaCost overrides it):
	  Scout Shortsword (15)                           6 light, 17 heavy
	  Frontier Sword, Runeblade, etc (18)             7 light, 20 heavy
	  Impact Falchion, Omega Greatblade (23)          9 light, 26 heavy
	A heavy is 2.85x a light. Against 100 Stamina and 12/s regen (paused
	RegenDelay after any spend, so it never refills mid-flurry): about 14
	light swings or 5 heavies in a row with a standard sword before you're
	winded. A shot (sidearm) costs 0.25 per point (3).

	Guard: holding it up drains GuardDrain per second (no regen while it's
	up), and each blow it takes costs BlockPerDamage per point of the blow
	(at least BlockMin): a rival's 9-11 damage hit costs about 5. A parry (a
	perfect block) costs nothing. A blow you can't pay for breaks your guard
	(GuardBreakSeconds) and lands in full.

	Out of Stamina: a heavy comes out as a light swing, a light swing still
	lands but WindedDamage weaker, and you can't raise your guard below
	BlockMin.
]]
Actions.Stamina = {
	PerDamage = 0.4,
	HeavyMult = 2.85,
	ShotPerDamage = 0.25,
	GuardDrain = 4,
	BlockPerDamage = 0.5,
	BlockMin = 3,
	RegenDelay = 0.8,
	WindedDamage = 0.6,
	GuardBreakSeconds = 1,
}
-- Stamina for one attack with `weapon` (a Classes gear entry).
function Actions.swingCost(weapon, heavy: boolean?): number
	local attack = weapon and weapon.Attack or {}
	local light = attack.StaminaCost
		or math.floor(
			(attack.Damage or 18)
					* (if attack.Kind == "Melee" then Actions.Stamina.PerDamage else Actions.Stamina.ShotPerDamage)
				+ 0.5
		)
	return if heavy then math.floor(light * Actions.Stamina.HeavyMult + 0.5) else light
end
Actions.AfterDodgeSeconds = 3
Actions.DoubleTap = 0.3 -- seconds between Space taps that make a roll
Actions.BlockLease = 0.6 -- release automatically if focus/disconnection drops an End packet
Actions.PerfectAt = 0.75
Actions.PerfectWindow = 0.09
Actions.OverchargeAt = 1.15
Actions.ComboWindow = 1.8
-- These timings are Saga's tuning. Damage and timing are always resolved on the server.
function Actions.charge(seconds)
	if seconds >= Actions.OverchargeAt then
		return { Heavy = false, Perfect = false, Scale = 0.65, Stage = "OVERCHARGED" }
	end
	local perfect = math.abs(seconds - Actions.PerfectAt) <= Actions.PerfectWindow
	return {
		Heavy = seconds >= Actions.Base.Heavy.Charge,
		Perfect = perfect,
		Scale = 1,
		Stage = if perfect then "PERFECT" elseif seconds >= Actions.Base.Heavy.Charge then "CHARGED" else "QUICK",
	}
end
-- Reject malformed remote payloads before resolving equipment or mutating combat state.
function Actions.validInput(action, a, b)
	if action == "CancelTech" or action == "CancelAttack" then
		return true
	elseif action == "BeginAttack" then
		return a == nil or a == "Left" or a == "Right"
	elseif action == "Attack" or action == "ReleaseAttack" then
		return Actions.finiteVector(a)
	elseif action == "Block" then
		return a == false or (a == true and Actions.finiteVector(b))
	elseif action == "Dodge" then
		return (a == nil or Actions.finiteVector(a)) and (b == nil or b == "Hop" or b == "Roll")
	elseif action == "RigManeuver" then
		return typeof(a) == "string" and #a <= 64 and Actions.finiteVector(b)
	elseif action == "Surge" then
		return (a == "Q" or a == "E" or a == "R") and Actions.finiteVector(b)
	end
	return false
end
function Actions.side(value)
	return if value == "Left" then "Left" else "Right"
end
function Actions.combo(previousSide, count, lastHit, side, now)
	return if previousSide
			and previousSide ~= side
			and lastHit
			and now - lastHit <= Actions.ComboWindow
		then math.min((count or 0) + 1, 3)
		else 1
end
function Actions.resolve(counts, weaponType, cooldownReduction)
	local result = {
		BasicDamage = 1,
		BasicCooldown = if weaponType == "Sword" then 0.65 else 0.45,
		HeavyDamage = 1.8,
		HeavyPvPDamage = 1.5,
		HeavyCooldown = 1.2,
		HeavyCrit = 0,
		Knockback = 12,
		DodgeCooldown = 3,
		DodgeDistance = 15,
		Invincible = 0.5,
		PvPInvincible = 0.3,
		BlockReduction = 0.5,
		BlockPvPReduction = 0.4,
		BlockArc = 120,
		Deflect = false,
		Stagger = 0,
	}
	for _, family in ArmorFamilies.Order do
		if (counts[family] or 0) >= 2 then
			local e = ArmorFamilies.Enhancements[family]
			result.BasicDamage *= e.BasicDamage or 1
			result.BasicCooldown /= e.AttackSpeed or 1
			result.Knockback *= e.Knockback or 1
			result.HeavyDamage *= e.HeavyDamage or 1
			result.HeavyPvPDamage *= e.HeavyDamage or 1
			result.HeavyCrit += e.HeavyCrit or 0
			result.DodgeCooldown *= e.DodgeCooldown or 1
			result.DodgeDistance *= e.DodgeDistance or 1
			result.Invincible = math.max(result.Invincible, e.Invincible or 0)
			result.BlockReduction = math.max(result.BlockReduction, e.BlockReduction or 0)
			result.BlockPvPReduction = math.max(result.BlockPvPReduction, e.BlockPvPReduction or 0)
			result.BlockArc *= e.BlockWidth or 1
			result.Deflect = result.Deflect or e.Deflect == true
			result.Stagger = math.max(result.Stagger, e.Stagger or 0)
		end
	end
	local multiplier = 1 - math.clamp(cooldownReduction or 0, 0, 0.6)
	result.HeavyCooldown *= multiplier
	result.DodgeCooldown *= multiplier
	return result
end
function Actions.finiteVector(v)
	return typeof(v) == "Vector3"
		and v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e6
		and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end
function Actions.canPvP(source, target, sourceInArena, targetInArena, sourceOptedIn, targetOptedIn, sameTeam)
	return source ~= target
		and sourceInArena
		and targetInArena
		and sourceOptedIn == true
		and targetOptedIn == true
		and not sameTeam
end
-- `kind` "Hop" has its own, shorter window; otherwise it's a roll.
function Actions.invulnerable(started, now, rules, pvp, kind)
	local window = if kind == "Hop"
		then (if pvp then Actions.Base.Hop.PvPInvincible else Actions.Base.Hop.Invincible)
		else (if pvp then rules.PvPInvincible else rules.Invincible)
	return started ~= nil and now >= started and now - started < window
end

-- Space taps: a second tap within DoubleTap of the last makes a roll.
function Actions.dodgeKind(lastTap: number?, now: number): string
	return if lastTap and now - lastTap <= Actions.DoubleTap then "Roll" else "Hop"
end
function Actions.blockMultiplier(rules, pvp, facingDot, projectile, heavy)
	if heavy or facingDot < math.cos(math.rad(rules.BlockArc / 2)) then
		return 1, false
	end
	if projectile and rules.Deflect then
		return 0, true
	end
	return 1 - (if pvp then rules.BlockPvPReduction else rules.BlockReduction), true
end
return Actions
