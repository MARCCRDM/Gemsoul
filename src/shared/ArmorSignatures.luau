-- Armor buff v1: permanent server-rolled identities; pure shared rules for UI and combat.
local GemConfig = require(script.Parent.GemConfig)
local ArmorSignatures = {}
ArmorSignatures.Version = 1
ArmorSignatures.Slots = { Helmet = "Helmets", Armor = "Armors", Gloves = "Gloves", Boots = "Boots", Shield = "Shields" }
ArmorSignatures.Pools = {
	Helmet = { "ChargeGain", "Countercharge", "Conductor", "Momentum", "Recycler" },
	Armor = { "LifeSteal", "Barrier" },
	Gloves = { "Riposte" },
	Boots = { "StaminaRefund", "Pursuit" },
	Shield = { "GuardEfficiency" },
}
ArmorSignatures.Definitions = {
 -- (StaminaCost: how much slower the wearer's stamina refills, the price of
 -- the strongest Charge traits.)
 Conductor={Name="Conductor",Slot="Helmet",Base=.20,Max=.40,Cooldown=0,Percent=true,StaminaCost=.15,
  Trigger="More Charge from every weapon hit you land. Cost: stamina refills 15% slower",
  Effect="+%s Charge from every hit you land: a light hit gives %s, a heavy %s (normally %s and %s)"},
 Momentum={Name="Momentum",Slot="Helmet",Base=4,Max=8,Cooldown=0,Unit="Charge",StaminaCost=.10,
  Trigger="Bonus Charge on every third damaging sword hit within 5 s. Cost: stamina refills 10% slower",
  Effect="+%s bonus Charge on every third damaging sword hit within 5 s"},
 Recycler={Name="Recycler",Slot="Helmet",Base=1,Max=2,Cooldown=0,Unit="Charge/s",StaminaCost=.15,
  Trigger="Charge every second for 3 s after a damaging sword hit. Cost: stamina refills 15% slower",
  Effect="+%s Charge a second for 3 s after a damaging sword hit (the next hit restarts it)"},
	ChargeGain = {
		Name = "Charge Gain",
		Slot = "Helmet",
		Base = 1,
		Max = 3,
		Cooldown = 1,
		Unit = "Charge",
		Trigger = "Extra Charge when a sword hit does damage; once a second",
		Effect = "+%s Charge when a sword hit does damage (once a second)",
	},
	Countercharge = {
		Name = "Countercharge",
		Slot = "Helmet",
		Base = 4,
		Max = 10,
		Cooldown = 4,
		Unit = "Charge",
		Trigger = "Charge when you time a block; once every 4 s",
		Effect = "+%s Charge when you time a block (once every 4 s)",
	},
	LifeSteal = {
		Name = "Life Steal",
		Slot = "Armor",
		Base = 0.02,
		Max = 0.05,
		Cooldown = 0,
		Percent = true,
		Trigger = "Heal a share of the sword damage you deal; anti-heal cuts it",
		Effect = "Heal %s of the sword damage you deal (anti-heal cuts it)",
	},
	Barrier = {
		Name = "Barrier",
		Slot = "Armor",
		Base = 6,
		Max = 15,
		Cooldown = 6,
		Unit = "absorption",
		Trigger = "A timed block gives you a damage shield for 3 s; once every 6 s",
		Effect = "A timed block gives you a shield that soaks %s damage for 3 s (once every 6 s)",
	},
	Riposte = {
		Name = "Riposte",
		Slot = "Gloves",
		Base = 0.10,
		Max = 0.25,
		Cooldown = 4,
		Percent = true,
		Trigger = "After a timed block, your next sword hit within 1.5 s deals more damage; once every 4 s",
		Effect = "After a timed block, your next sword hit within 1.5 s deals +%s damage (once every 4 s)",
	},
	StaminaRefund = {
		Name = "Stamina Refund",
		Slot = "Boots",
		Base = 0.10,
		Max = 0.30,
		Cooldown = 3,
		Percent = true,
		Trigger = "Dodge an attack and get some of the dodge's stamina back; once every 3 s",
		Effect = "Dodge an attack and get %s of the dodge's stamina back (once every 3 s)",
	},
	Pursuit = {
		Name = "Pursuit",
		Slot = "Boots",
		Base = 0.08,
		Max = 0.18,
		Cooldown = 6,
		Percent = true,
		Trigger = "A heavy sword hit makes you faster for 2 s; once every 6 s",
		Effect = "A heavy sword hit makes you %s faster for 2 s (once every 6 s)",
	},
	GuardEfficiency = {
		Name = "Guard Efficiency",
		Slot = "Shield",
		Base = 0.15,
		Max = 0.35,
		Cooldown = 0,
		Percent = true,
		Trigger = "Blocked hits drain less of your stamina",
		Effect = "Blocked hits drain %s less of your stamina",
	},
}
-- Charge a landed weapon hit pays without perks, light and heavy (the same as
-- CombatTechnology.Resources.Charge.OnHit / OnHeavy: tested to match), for
-- the traits' wording.
ArmorSignatures.HitCharge = { Light = 5, Heavy = 10 }
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
-- A number as the traits show it: one decimal at most, "%" for shares.
local function shown(def, v: number): string
	local n = if def.Percent then v * 100 else v
	local text = string.format("%.1f", n):gsub("%.0$", "")
	return if def.Percent then text .. "%" else text
end
-- A resolved trait in plain words: Effect (what it does, its value in it),
-- Cost (its stamina trade-off, if it has one), Range (what it rolls
-- between) and Note (what Charge is for, on the Charge traits).
function ArmorSignatures.explain(sig)
	local d = sig.Definition
	local effect
	if sig.Id == "Conductor" then
		local light, heavy = ArmorSignatures.HitCharge.Light, ArmorSignatures.HitCharge.Heavy
		effect = string.format(
			d.Effect,
			shown(d, sig.Value),
			shown({}, light * (1 + sig.Value)),
			shown({}, heavy * (1 + sig.Value)),
			shown({}, light),
			shown({}, heavy)
		)
	else
		effect = string.format(d.Effect or d.Trigger, shown(d, sig.Value))
	end
	local charge = sig.Id == "Conductor" or (d.Unit and string.find(d.Unit, "Charge", 1, true) ~= nil)
	return {
		Effect = effect,
		Cost = if d.StaminaCost
			then string.format("Cost: your stamina refills %d%% slower", math.floor(d.StaminaCost * 100 + 0.5))
			else nil,
		Range = string.format("Rolls %s to %s; rarer gear and a better gem raise it", shown(d, d.Base), shown(d, d.Max)),
		Note = if charge then "Charge fills your Q, E and R surges" else nil,
	}
end
function ArmorSignatures.describe(roll, gem)
	local sig = ArmorSignatures.resolve(roll, gem)
	if not sig then
		return "", ""
	end
	local plain = ArmorSignatures.explain(sig)
	return sig.Definition.Name,
		plain.Effect
			.. "."
			.. (if plain.Cost then " " .. plain.Cost .. "." else "")
			.. (if sig.Affinity > 0
				then string.format(" Matching affinity +%g%% (capped).", sig.Affinity * 100)
				else "")
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
	local bonus=activate(st, perks, "ChargeGain", now) or 0
 if perks and perks.Momentum then
  r.Hits=if now>(r.HitUntil or 0) then 1 else (r.Hits or 0)+1
  r.HitUntil=now+5
  if r.Hits>=3 then bonus+=perks.Momentum.Value;r.Hits=0 end
 end
 if perks and perks.Recycler then r.RecyclerUntil=now+3 end
 return bonus, actualDamage * (perks.LifeSteal and perks.LifeSteal.Value or 0)
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
function ArmorSignatures.chargeMultiplier(perks)
 return 1+(perks and perks.Conductor and perks.Conductor.Value or 0)
end
function ArmorSignatures.staminaMultiplier(perks)
 local slower = 0
 for id in perks or {} do
  local def = ArmorSignatures.Definitions[id]
  slower = math.max(slower, def and def.StaminaCost or 0)
 end
 return 1 - slower
end
function ArmorSignatures.recycler(st,perks,now,elapsed)
 local untilAt=runtime(st).RecyclerUntil or 0
 local active=math.clamp(untilAt-(now-elapsed),0,elapsed)
 return active*(perks and perks.Recycler and perks.Recycler.Value or 0)
end
return ArmorSignatures
