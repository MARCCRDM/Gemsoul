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
	Dodge = { Name = "Dodge", Cooldown = 3, Distance = 15, Duration = 0.25, Invincible = 0.5, PvPInvincible = 0.3 },
	Block = { Name = "Block", Reduction = 0.5, PvPReduction = 0.4, Arc = 120 },
}
Actions.AfterDodgeSeconds = 3
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
function Actions.invulnerable(started, now, rules, pvp)
	return started ~= nil and now >= started and now - started < (if pvp then rules.PvPInvincible else rules.Invincible)
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
