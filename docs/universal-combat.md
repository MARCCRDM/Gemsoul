# Universal Warrior combat — first playable implementation

The dashboard now provides **Train** and **PvP Arena** entry buttons. Both use the existing Arena and four universal actions. Training visitors are excluded from player damage. PvP requires both players to opt in and remain on the Arena floor. Teammates are excluded; arrival grants three seconds of protection. Leave Arena returns to the dashboard, and respawning ends participation.

| Action | PC | Touch | Base behavior |
|---|---|---|---|
| Attack | Tap left click | Tap Attack | 100% weapon damage; 0.45s pistol / 0.65s sword recovery |
| Heavy | Hold left click | Hold Attack or tap Heavy | Charges for 0.45s; 180% PvE / 150% PvP damage; 1.2s recovery; breaks frontal guard |
| Dodge | Space | Dodge button | Movement direction, or facing when stationary; 15 studs; 3s cooldown; 0.5s PvE / 0.3s PvP immunity |
| Block | Hold right click | Hold Block | 120° frontal coverage; 50% PvE / 40% PvP reduction; attacks unavailable while blocking |

Space retains its normal behavior outside combat. Block slows movement to 60%; a broken guard cannot be raised for 0.8s. Dodge motion lasts 0.25s. Lost focus cancels charging and blocking, and the server releases a block after 0.6s without a held-input refresh.

## Armor enhancements

Two matching pieces activate a family's action enhancements. Matching weapons count toward family totals. Hybrid builds combine enhancements from each qualifying family. Passive 2/4/6-piece stat bonuses remain in `ArmorFamilies`; active ability picks and ultimates are retired.

| Family | Attack | Heavy | Dodge | Block |
|---|---|---|---|---|
| Prospector | +10% damage | +15% knockback | -15% cooldown | +20% frontal width |
| Skirmisher | +15% attack speed | +20 percentage points critical chance | +25% distance | Deflects light projectiles |
| Juggernaut | +10% stagger chance | +25% damage | -20% distance; 0.75s PvE immunity | 65% PvE / 50% PvP reduction |

PvP dodge immunity remains 0.3s for every family. Cooldown-reduction bonuses affect Heavy and Dodge. The Skirmisher six-piece bonus grants +10% damage for three seconds after the universal Dodge. Critical chance remains capped at 75%.

## Gem integration

The incoming gem metric framework is integrated: Size sets magnitude, Clarity sets duration/recharge, and Precision sets trigger probability. Equipped elemental affinity affixes feed these calculations.

- Thermal attacks apply a refreshing burn; critical burns apply PvP Grievous Wounds.
- Cryo attacks slow and may freeze, with PvP diminishing returns.
- Corrosive attacks shred armor and may apply vulnerability and Mortal Strike.
- Ion attacks arc between eligible targets and can execute low-health targets; PvP permits one jump and disables stun.
- Defensive gems raise shields when Block is raised, then recharge according to their metrics. Thermal shields reflect 10% of blocked Thermal damage, with Precision-based reflection procs. Cryo supplies resistance and extended shields, Corrosive cleanses and applies a nearby corrosion aura while blocking, and Ion improves recharge and can deflect.

All five defensive sockets contribute their metrics. Re-raising Block cannot bypass shield recharge. PvP slows/shreds are capped and use the strongest active effect. CC duration diminishes over repeated applications; cleanses preserve that history. Healing through `CombatServer.heal` applies healing received and the combined 50% anti-heal ceiling.

## Server checks and validation

The server owns damage, target selection, cooldowns, heavy-charge timing, guard state and dodge motion. Hits check range, aim, wall obstruction, eligibility and dodge immunity. Heavy is derived from a server-recorded charge; client-provided damage values are never accepted. Legacy Ability and ultimate packets have no handler. Status damage stops after either participant loses PvP eligibility, and session transitions clear combat state.

Validation completed: 64 executable action/server/session checks; equipment and save regressions; 6,995 gem metric/affix/crowd-control checks; expedition/trading regressions; gem preview and drag tests; clean lint for new combat modules; successful Rojo place build.

This is the Arena combat foundation. Ranked queues, rounds, wagers and match rewards are not part of this implementation. A two-player Roblox Studio playtest is still required for live latency, movement and touch-layout review. Nothing has been published to Roblox.
