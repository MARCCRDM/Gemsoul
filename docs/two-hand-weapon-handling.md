# Two-hand weapon handling

Twin Blades, Lance, Greataxe and Warhammer occupy Weapon and Shield together. The saved shield remains owned and is restored when switching back to one-handed equipment. While occupied, its stats, quality, gem defense, affinity affixes, passive and set piece do not apply. Equipping another shield is rejected until a one-handed weapon is selected.

| Type | Base hit | Attack interval | Base DPS before perks |
|---|---:|---:|---:|
| Cleaver + shield | 18 | 0.65s | 27.69 |
| Twin Blades | 14 | 0.44s | 31.82 |
| Lance | 20 | 0.62s | 32.26 |
| Greataxe | 31 | 0.95s | 32.63 |
| Warhammer | 35 | 1.05s | 33.33 |

Two-hand guard reduces incoming damage 30% PvE / 25% PvP within a 90-degree arc. Shield defaults remain 50% / 40% within 120 degrees, with existing family enhancements. Two-hand family bonuses cannot upgrade the guard into a shield. Existing parry, stamina and heavy guard-break timing remains shared.

First-person viewmodels now raise the weapons themselves and recoil on blocked hits. Twin blades cross; polearms and heavy weapons brace across the view. Off-hand gloves are shown for dual weapons or as a support hand. Replicated weapon attributes select corresponding world-body guards through RivalPose for players and AI; returning to a one-handed weapon restores shield guard. Existing input paths cover mouse, controller and touch.

Verification: combat regression suite covers damage budgets, hidden shield stat/gem/passive removal, restoring saved equipment, world guard raise/recoil/recovery and existing combat rules. Compilation and Rojo build checked. Live first-person framing, hand contact, and multiplayer replication still require Studio/playtest visual verification.
