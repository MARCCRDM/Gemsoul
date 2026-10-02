-- One passive equipment budget, independent of armor ratings and temporary abilities.
local Balance = {}
Balance.MaxDamageReduction = 0.20
Balance.MaxCooldownReduction = 0.60
Balance.MaxCriticalChance = 0.75
Balance.MaxHazardResistance = 0.60
Balance.UtilityCooldowns = { Reflection = 25, PhaseDodge = 30, FirstHitGuard = 30 }
function Balance.passiveDamageMultiplier(taken, resistance)
	return math.max(
		1 - Balance.MaxDamageReduction,
		math.clamp(taken or 1, 0, 1) * (1 - math.clamp(resistance or 0, 0, 1))
	)
end
function Balance.cooldownMultiplier(value)
	return math.clamp(value or 1, 1 - Balance.MaxCooldownReduction, 1)
end
function Balance.criticalChance(speed, bonus)
	-- Rating contributes at most 2.5 points, leaving room for item critical bonuses.
	return math.clamp(0.05 + math.min(math.max(speed, 0) / 4000, 0.025) + (bonus or 0), 0, Balance.MaxCriticalChance)
end
function Balance.hazardResistance(value)
	return math.clamp(value or 0, 0, Balance.MaxHazardResistance)
end
-- Future utility handlers must share the player's gate per utility, not per item.
-- Pass server monotonic time; consuming this gate does not execute the utility.
function Balance.consumeUtility(gates, utility, now)
	local cooldown = Balance.UtilityCooldowns[utility]
	if not cooldown or now < (gates[utility] or 0) then
		return false
	end
	gates[utility] = now + cooldown
	return true
end
return Balance
