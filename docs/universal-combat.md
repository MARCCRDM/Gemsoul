# Universal Warrior combat — first-person arena

The dashboard now provides **Train** and **PvP Arena** entry buttons. Both use the existing Arena and four universal actions. Training visitors are excluded from player damage. PvP requires both players to opt in and remain on the Arena floor. Teammates are excluded; arrival grants three seconds of protection. Leave Arena returns to the dashboard, and respawning ends participation.

| Action | PC | Touch | Base behavior |
|---|---|---|---|
| Attack | Tap LMB; Q left / E right | Tap Left / Right | 100% weapon damage; 0.45s pistol / 0.65s sword recovery; alternate sides for combos |
| Heavy | Hold then release LMB / Q / E | Hold then release Left / Right | Heavy after 0.45s; 180% PvE / 150% PvP damage; 1.2s recovery; breaks frontal guard |
| Dodge | Space | Dodge button | Movement direction, or facing when stationary; 15 Stamina; 15 studs; 3s cooldown; 0.5s PvE / 0.3s PvP immunity |
| Block | Hold right click | Hold Block | 120° frontal coverage; 50% PvE / 40% PvP reduction; attacks unavailable while blocking |

See [Combat technology](combat-technology.md) for the Stamina/Charge resources, six Rig Maneuvers, six Gem Surges and their controls. Space retains its normal behavior outside combat. Block slows movement to 60%; a broken guard cannot be raised for 0.8s. Dodge motion lasts 0.25s. Lost focus cancels charging and blocking, and the server releases a block after 0.6s without a held-input refresh.

## First-person presentation and timing

Combat locks the camera to first person at 75° FOV. Center-screen aiming works with both mouse and touch. The local view displays copies of the actual equipped weapon, shield and gloves, retaining original geometry, materials, finishes and gems. These presentation copies cannot collide or become raycast targets. The real character remains visible to opponents. Exiting combat or dying restores zoom, FOV, cursor and body visibility.

The HUD shows opponent name and health above the encounter, a center reticle and charge bar, personal health and shield amount, side-specific attack controls, central Guard, Dodge and Leave Arena. **Tab** frees the desktop cursor for Leave Arena; Tab again recaptures it. Left click automatically alternates sides; Q/E and touch buttons choose explicitly.

- Release at **0.75 seconds ±0.09s** for a guaranteed critical. The indicator turns gold during this window.
- Holding at least **1.15s** overcharges: the indicator turns red and the release deals 65% basic damage. Nothing releases automatically; charges expire after three seconds.
- Successful alternating hits within **1.8s** build a three-hit combo: +0%, +10%, then +20% damage. Repeating a side restarts the chain. A miss or guarded hit clears it; the server advances it once per swing, not once per victim.
- Raising guard opens a **0.3s high-block window** against frontal non-heavy melee attacks: 75% PvE / 65% PvP reduction and a brief counter opening (0.5s enemy stun / 0.25s player stun, subject to PvP diminishing returns). Each raise can parry once, and high block can refresh only every 1.5s. Held guard packets never restart that window. Heavy remains the guard-breaking counter.

All timing and combo damage are server-derived. The client submits an attack side and aim, never a charge strength or critical claim. Saga's timings are its own tuning. Alternating swings and reactive blocking follow the combat principles described in Bethesda's [Blades Arena guide](https://elderscrolls.bethesda.net/en-US/news/6k35P5RS5vdln7ZY1lZpqG/blades-arena-beginners-guide).

## Armor enhancements

Two matching pieces activate a family's action enhancements. Matching weapons count toward family totals. Hybrid builds combine enhancements from each qualifying family. Passive 2/4/6-piece stat bonuses remain in `ArmorFamilies`; retired class-specific technique picks and ultimates are removed; the shared technology kit is universal.

| Family | Attack | Heavy | Dodge | Block |
|---|---|---|---|---|
| Prospector | +10% damage | +15% knockback | -15% cooldown | +20% frontal width |
| Skirmisher | +15% attack speed | +20 percentage points critical chance | +25% distance | Deflects light projectiles |
| Juggernaut | +10% stagger chance | +25% damage | -20% distance; 0.75s PvE immunity | 65% PvE / 50% PvP reduction |

PvP dodge immunity remains 0.3s for every family. Cooldown-reduction bonuses affect Heavy and Dodge. The Skirmisher six-piece bonus grants +10% damage for three seconds after the universal Dodge. Random critical chance remains capped at 75%; a correctly timed perfect release guarantees one critical, without stacking a second critical multiplier.

## Gem integration

The incoming gem metric framework is integrated: Size sets magnitude, Clarity sets duration/recharge, and Precision sets trigger probability. Equipped elemental affinity affixes feed these calculations.

- Thermal attacks apply a refreshing burn; critical burns apply PvP Grievous Wounds.
- Cryo attacks slow and may freeze, with PvP diminishing returns.
- Corrosive attacks shred armor and may apply vulnerability and Mortal Strike.
- Ion attacks arc between eligible targets and can execute low-health targets; PvP permits one jump and disables stun.
- Defensive gems raise shields when Block is raised, then recharge according to their metrics. Thermal shields reflect 10% of blocked Thermal damage, with Precision-based reflection procs. Cryo supplies resistance and extended shields, Corrosive cleanses and applies a nearby corrosion aura while blocking, and Ion improves recharge and can deflect.

All five defensive sockets contribute their metrics. Re-raising Block cannot bypass shield recharge. PvP slows/shreds are capped and use the strongest active effect. CC duration diminishes over repeated applications; cleanses preserve that history. Healing through `CombatServer.heal` applies healing received and the combined 50% anti-heal ceiling.

## Server checks and validation

The server owns damage, target selection, cooldowns, heavy-charge timing, guard state and dodge motion. Hits check range, aim, wall obstruction, eligibility and dodge immunity. Heavy is derived from a server-recorded charge; client-provided damage values are never accepted. Retired class-technique and ultimate packets have no handler. Status damage stops after either participant loses PvP eligibility, and session transitions clear combat state.

Validation completed: 82 executable action/server/session checks and 12 first-person camera/cursor/visibility lifecycle checks; equipment and save regressions; 6,995 gem metric/affix/crowd-control checks; expedition/trading regressions; gem preview and drag tests; clean lint for new combat modules; successful Rojo place build.

This is the Arena combat foundation. Ranked queues, rounds, wagers and match rewards are not part of this implementation. A two-player Roblox Studio playtest is still required for live latency, movement and touch-layout review. Nothing has been published to Roblox.
