-- Armor buff v1: permanent server-rolled identities; pure shared rules for UI and combat.
local GemConfig = require(script.Parent.GemConfig)
local ArmorSignatures = {}
ArmorSignatures.Version = 1
ArmorSignatures.Slots = { Helmet = "Helmets", Armor = "Armors", Gloves = "Gloves", Boots = "Boots", Shield = "Shields" }
ArmorSignatures.Pools = {
	Helmet = { "ChargeGain", "Countercharge" },
	Armor = { "LifeSteal", "Barrier" },
	Gloves = { "Riposte" },
	Boots = { "StaminaRefund", "Pursuit" },
	Shield = { "GuardEfficiency" },
}
ArmorSignatures.Definitions = {
	ChargeGain = {
		Name = "Charge Gain",
		Slot = "Helmet",
		Base = 1,
		Max = 3,
		Cooldown = 1,
		Unit = "Charge",
		Trigger = "A sword hit deals health damage",
	},
	Countercharge = {
		Name = "Countercharge",
		Slot = "Helmet",
		Base = 4,
		Max = 10,
		Cooldown = 4,
		Unit = "Charge",
		Trigger = "Successfully time a block",
	},
	LifeSteal = {
		Name = "Life Steal",
		Slot = "Armor",
		Base = 0.02,
		Max = 0.05,
		Cooldown = 0,
		Percent = true,
		Trigger = "Heal from actual sword damage; anti-heal applies",
	},
	Barrier = {
		Name = "Barrier",
		Slot = "Armor",
		Base = 6,
		Max = 15,
		Cooldown = 6,
		Unit = "absorption",
		Trigger = "Timed block grants a non-stacking barrier for 3s",
	},
	Riposte = {
		Name = "Riposte",
		Slot = "Gloves",
		Base = 0.10,
		Max = 0.25,
		Cooldown = 4,
		Percent = true,
		Trigger = "Timed block empowers your next sword hit within 1.5s",
	},
	StaminaRefund = {
		Name = "Stamina Refund",
		Slot = "Boots",
		Base = 0.10,
		Max = 0.30,
		Cooldown = 3,
		Percent = true,
		Trigger = "Avoid an incoming attack: refund this share of your dodge cost",
	},
	Pursuit = {
		Name = "Pursuit",
		Slot = "Boots",
		Base = 0.08,
		Max = 0.18,
		Cooldown = 6,
		Percent = true,
		Trigger = "A heavy sword hit grants movement speed for 2s",
	},
	GuardEfficiency = {
		Name = "Guard Efficiency",
		Slot = "Shield",
		Base = 0.15,
		Max = 0.35,
		Cooldown = 0,
		Percent = true,
		Trigger = "Reduce stamina spent absorbing a blocked hit",
	},
}
function ArmorSignatures.isSword(weapon)
 return weapon ~= nil and (weapon.WeaponType == "Sword" or weapon.Look == "SwordShield")
end
function ArmorSignatures.ensure(roll, slot, rng)
	local pool = ArmorSignatures.Pools[slot]
	if not roll or not pool then
		return
	end
	if
		roll.SignatureVersion == ArmorSignatures.Version
		and ArmorSignatures.Definitions[roll.Signature]
		and ArmorSignatures.Definitions[roll.Signature].Slot == slot
	then
		return
	end
	roll.Signature = pool[rng:NextInteger(1, #pool)]
	roll.SignatureVersion = ArmorSignatures.Version
end
function ArmorSignatures.resolve(roll, gem, ranked)
	local def = roll and ArmorSignatures.Definitions[roll.Signature]
	if not def then
		return nil
	end
	local floor = math.clamp(((roll.Rarity or 1) - 1) * 0.05, 0, 0.20)
	local quality = if gem then math.clamp(((gem.Size or 1) + (gem.Clarity or 1) + (gem.Cut or 1)) / 30, 0, 1) else 0
	local affinity = 0
	for _, affix in roll.Affixes or {} do
		local info = GemConfig.AffixById[affix.Id]
		if gem and info and info.Side == "Defense" and info.Element == gem.Element then
			affinity = math.max(affinity, math.clamp(affix.Bonus or 0, 0, 0.20))
		end
	end
	-- Ranked keeps the selected behavior but normalizes rarity, quality and affinity.
	if ranked then
		floor, quality, affinity = 0, 0.5, 0
	end
	local base = def.Base + (def.Max - def.Base) * floor
	local value = math.min(def.Max, base + (def.Max - base) * quality * (1 + affinity))
	return { Id = roll.Signature, Definition = def, Value = value, Base = base, Affinity = affinity }
end
function ArmorSignatures.loadout(loadout, ranked)
	local result = {}
	for slot, kind in ArmorSignatures.Slots do
		local roll = loadout.GearRolls and loadout.GearRolls[kind] and loadout.GearRolls[kind][loadout[slot]]
		local sig = ArmorSignatures.resolve(roll, loadout[slot .. "Gem"], ranked)
		if sig and sig.Definition.Slot == slot then
			result[sig.Id] = sig
		end
	end
	return result
end
function ArmorSignatures.describe(roll, gem)
	local sig = ArmorSignatures.resolve(roll, gem)
	if not sig then
		return "", ""
	end
	local d = sig.Definition
	local function fmt(v)
		return if d.Percent then string.format("%.1f%%", v * 100) else string.format("%.1f %s", v, d.Unit or "")
	end
	return d.Name,
		string.format(
			"%s. %s -> %s%s%s",
			d.Trigger,
			fmt(sig.Base),
			fmt(sig.Value),
			if d.Cooldown > 0 then string.format("; %gs cooldown", d.Cooldown) else "",
			if sig.Affinity > 0
				then string.format("; matching affinity +%g%% to enchantment (capped)", sig.Affinity * 100)
				else ""
		)
end
local function runtime(st)
	st.ArmorBuffs = st.ArmorBuffs or { Ready = {}, Windows = {} }
	return st.ArmorBuffs
end
local function activate(st, perks, id, now)
	local sig = perks and perks[id]
	local r = runtime(st)
	if not sig or now < (r.Ready[id] or 0) then
		return nil
	end
	r.Ready[id] = now + sig.Definition.Cooldown
	return sig.Value
end
-- A sliding window, not a resettable wall-clock bucket. Only accepted output is recorded.
function ArmorSignatures.budget(st, key, amount, cap, now)
	local r = runtime(st)
	local entries = r.Windows[key] or {}
	r.Windows[key] = entries
	local used = 0
	for i = #entries, 1, -1 do
		if now - entries[i].At >= 10 then
			table.remove(entries, i)
		else
			used += entries[i].Amount
		end
	end
	local accepted = math.max(0, math.min(amount, cap - used))
	if accepted > 0 then
		table.insert(entries, { At = now, Amount = accepted })
	end
	return accepted
end
function ArmorSignatures.timedBlock(st, perks, now)
	local r = runtime(st)
	local barrier = activate(st, perks, "Barrier", now)
	if barrier then
		r.Barrier, r.BarrierUntil = barrier, now + 3
	end
	local riposte = activate(st, perks, "Riposte", now)
	if riposte then
		r.Riposte, r.RiposteUntil = riposte, now + 1.5
	end
	return activate(st, perks, "Countercharge", now) or 0
end
function ArmorSignatures.attackMultiplier(st, now)
	local r = runtime(st)
	local bonus = if now < (r.RiposteUntil or 0) then r.Riposte or 0 else 0
	r.RiposteUntil = 0
	return 1 + bonus
end
function ArmorSignatures.hit(st, perks, now, actualDamage, heavy)
	if actualDamage <= 0 then
		return 0, 0
	end
	local r = runtime(st)
	if heavy then
		local speed = activate(st, perks, "Pursuit", now)
		if speed then
			r.Speed, r.SpeedUntil = speed, now + 2
		end
	end
	return activate(st, perks, "ChargeGain", now) or 0, actualDamage * (perks.LifeSteal and perks.LifeSteal.Value or 0)
end
function ArmorSignatures.dodged(st, perks, now, cost, dodgeId)
	local r = runtime(st)
	if not dodgeId or r.RefundedDodge == dodgeId then
		return 0
	end
	r.RefundedDodge = dodgeId
	return (activate(st, perks, "StaminaRefund", now) or 0) * math.max(0, cost or 0)
end
function ArmorSignatures.absorb(st, damage, now)
	local r = runtime(st)
	local blocked = if now < (r.BarrierUntil or 0) then math.min(damage, r.Barrier or 0) else 0
	r.Barrier = math.max(0, (r.Barrier or 0) - blocked)
	return damage - blocked, blocked
end
function ArmorSignatures.guardMultiplier(perks)
	return 1 - (perks and perks.GuardEfficiency and perks.GuardEfficiency.Value or 0)
end
function ArmorSignatures.speed(st, now)
	local r = runtime(st)
	return if now < (r.SpeedUntil or 0) then 1 + (r.Speed or 0) else 1
end
return ArmorSignatures
