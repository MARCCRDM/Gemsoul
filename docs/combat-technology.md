# Saga Miners combat technology

Implemented from the approved Combat Terminology & Universe Conversion brief. Combat remains first person; every player is a Warrior whose equipment defines their build. All twelve techniques are available to review in the Augment Tree. Only unlocked techniques appear in the combat cycling controls. Gem Surges require compatible socketed gemstones; Kinetic Ram requires a shield.

## Resources and controls

| Resource | HUD color | Capacity | Regeneration | Powers |
|---|---|---|---|---|
| Health | Red | Equipment-derived | Existing healing rules | Survival |
| Stamina | Green | 100 | 12/s | Dodge and Rig Maneuvers |
| Charge | Blue | 100 | 7/s with a socketed gem | Gem Surges |

The capacities and regeneration rates are initial tuning; the brief specifies costs but not regeneration. Unsocketing every gem clears Charge. Ordinary Dodge costs 15 Stamina. Charges, barriers and timed effects belong to the combat session and reset when it ends.

LMB attacks, Q/E choose swing sides, RMB guards, and Space dodges. **Z cycles Rig Maneuvers; R triggers the selected maneuver. X cycles Gem Surges; F triggers the selected surge.** Hold F for Cryo Stream and release to stop. Touch has matching trigger and cycle buttons. Tab frees the desktop cursor. K opens the Augment Tree. The ? button opens the combat guide. The dashboard also has a visible AUGMENT TREE button.

The stored **Charge resource** is distinct from the **attack wind-up timing indicator**. Holding a normal weapon attack does not spend Charge.

## Rig Maneuvers

| Technique | Stamina | Behavior |
|---|---:|---|
| Hydraulic Slam | 30 | 180% weapon damage, breaks frontal high and sustained guard |
| Servo Flurry | 20 | Two 70% strikes, separated by 0.16s |
| Kinetic Ram | 25 | Shield pulse, 120% damage, brief stagger |
| Stim Dodge | 15 | Server-controlled dodge and healing equal to 10% maximum Health; healing modifiers and anti-heal apply |
| Breach Hammer | 40 | One-second wind-up, then 250% damage |
| Armor Piercer | 35 | 100% weapon damage bypasses guard; Defense, barriers, dodge immunity and protection still apply |

## Gem Surges

| Surge | Charge | Socket requirement | Behavior |
|---|---:|---|---|
| Thermal Burst | 25 | Thermal | Plasma detonation, 8-stud radius, up to 35 studs away; applies metric-derived burn |
| Energy Siphon | 20 | Any gem | Four-second field absorbs up to 40 post-mitigation damage; converts half the intercepted damage into Charge |
| Cryo Lance | 25 | Cryo | Aimed cryogenic shard, up to 45 studs, damage and brief stun |
| Cryo Stream | 15/s | Cryo | Held beam, up to 24 studs, damage and 25% slow; paid in quarter-second slices |
| Cryo Shield | 30 | Cryo | Five-second barrier absorbs 30 + 3 × gem Size damage |
| Resonance Echo | 40 | Any gem | Duplicates landed normal weapon strikes for five seconds; duplicates do not trigger another echo or another gem proc |

Unspecified surge damage uses weapon damage and Power, scaled by the powering gem's Size. Thermal Burst and Cryo Lance use a 100% base; Cryo Stream uses 45% per second. These are explicit first-playtest tuning, rather than numbers supplied by the brief. Effects from matching gems in either weapons or armor can power a surge. Internal saved element IDs (`Fire`, `Frost`, `Poison`, `Shock`) remain compatible with existing inventory data; presentation uses Thermal, Cryo, Corrosive and Ion.

## Universe language

Active code and UI use **Rig Maneuvers**, **Gem Surges**, **Passive Augments**, **Charge**, **Augment Tree**, and **Augment Points**. The instructor explains current controls. Existing gear augments remain automatic and retain their stat budgets. The shared technology catalog records Blade Calibration, Cleaver Calibration, Mobility Augment, Stamina Recycler, Charge Recycler and Thermal Overcharge.

Consumable naming is standardized as **Stim Shot**, **Charge Cell**, and **Energy Drink**. These are catalog conventions; this change does not introduce a consumable inventory or a new purchase economy. The Augment Tree now has 18 connected nodes across three branches. See [Augment Tree progression](augment-tree.md) for saved unlocks, node prices, XP awards and free resets.

Retired saved technique picks are discarded during profile normalization. Equipment IDs, rarity rolls, gem IDs and asset geometry are preserved. Pulse VFX use straight emitter beams, expanding plasma discs and segmented field panels.

## Authority and validation

The server validates costs, finite aim, range, walls, socket compatibility, shield ownership, recovery, death, town restrictions and PvP opt-in. Both delayed Flurry hits and Breach Hammer wind-ups recheck eligibility at impact. Blocking, dodging, losing focus or being stunned cancels pending techniques and channels. Lost channel refreshes expire after 0.5s. PvP control effects use the existing duration cap and diminishing returns; barriers and healing respect existing defensive rules.

The combat regression runner includes executable tests for all twelve techniques, resource costs, regeneration, missing/wrong gems, shield requirements, wind-up cancellation, channel billing/release, echo damage, siphon conversion, walls and PvP exclusions. Live two-player and touch playtests in Roblox Studio are still required. Nothing has been published to Roblox.
