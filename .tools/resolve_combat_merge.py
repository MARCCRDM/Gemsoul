from pathlib import Path
import re,subprocess
r=Path(__file__).resolve().parents[1]
p=r/'src/server/Systems/CombatServer.luau'
s=p.read_text()
# Keep universal-action code in conflict hunks, then integrate the incoming metrics below.
s=re.sub(r'^<<<<<<< HEAD\n(.*?)^=======\n.*?^>>>>>>> [^\n]+\n',lambda m:m.group(1),s,flags=re.M|re.S)
p.write_text(s)
p=r/'src/shared/GemConfig.luau'
s=subprocess.check_output(['git','show',':3:src/shared/GemConfig.luau'],cwd=r,text=True)
addition='''-- Universal actions consume the independent Size/Clarity/Precision metrics.
function GemConfig.actionValues(gem: Gem, action: string, opts): { [string]: any }
 local v = GemConfig.stats(gem, if action == "Block" then "Shield" else "Weapon", opts)
 if action == "Block" then
  return { Shield = v.ShieldAmount, Duration = GemConfig.Rules.ShieldBaseDuration + (v.ShieldDuration or 0),
   Cooldown = math.max(GemConfig.Rules.ShieldMinCooldown, GemConfig.Rules.ShieldBaseCooldown - (v.CooldownCut or 0)) / (1 + (v.RechargeRate or 0)),
   ReflectThermal = if gem.Element == "Fire" then 0.10 else nil, ReflectChance = v.ReflectChance,
   Cleanse = gem.Element == "Poison", CleanseInterval = if v.CleanseRate then GemConfig.cleanseInterval(v.CleanseRate) else nil,
   Resist = v.Resistance, Deflect = v.DeflectChance, Aura = v.AuraShred }
 end
 return { Burn = v.BurnDamage, Duration = v.BurnDuration or v.SlowDuration or v.DebuffDuration,
  Ignite = v.IgniteChance, Slow = v.SlowAmount, Freeze = v.FreezeChance, FreezeSeconds = v.FreezeSeconds,
  Sunder = v.ArmorShred, Vulnerable = v.VulnerableChance, VulnerableAmount = v.VulnerableAmount,
  Arc = v.ArcDamage, Chain = v.ChainLength, Stun = v.StunChance, StunSeconds = v.StunSeconds,
  Execute = v.ExecuteThreshold, HealingReduction = v.HealingReduction }
end
'''
s=s.replace('-- Gems no longer add flat ratings;',addition+'\n-- Gems no longer add flat ratings;')
p.write_text(s)
