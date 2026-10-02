# Augment Tree

Open **AUGMENT TREE** in the dashboard's Combat Arena panel, or press **K**. The Arena HUD has the same button. The arena instructor and combat guide also link to the tree.

The screen shows connected nodes, prerequisites, unlocked/locked status, point prices, descriptions, available points and progress toward the next point. Desktop shows all three branches together; narrow screens show one branch with tabs. Select a node, then choose **UNLOCK**. **RESET & REFUND** returns spent points and keeps earned XP.

## Initial progression tuning

- Three starting Augment Points. Hydraulic Slam and Thermal Burst are free starting nodes.
- One additional point per 150 base activity XP, up to 24 total points. Mining, selling, socketing, daily rewards and eligible enemy kills contribute through existing XP awards. Season XP boosts do not multiply Augment XP.
- Lifetime Augment XP persists independently of the season. Returning profiles are seeded from their existing season XP once.
- Unlocks and point accounting are saved in profile version 10. The server recomputes spent points from valid learned nodes; unknown nodes, invalid prerequisites and excess spending are discarded during normalization.
- Unlock or reset in the dashboard/town. Arena sessions, mining expeditions and world combat areas allow viewing but prevent build changes.
- Only unlocked Rig Maneuvers and Gem Surges appear when cycling Z/X. Physical base attacks, Heavy, Dodge and Block remain universal.

These are explicit first-pass tuning values because the conversion brief did not specify point prices or progression speed.

## Nodes

| Branch | Node | Points | Prerequisite |
|---|---|---:|---|
| Rig Maneuvers | Hydraulic Slam | Free | Starting node |
| Rig Maneuvers | Servo Flurry | 1 | Hydraulic Slam |
| Rig Maneuvers | Kinetic Ram | 1 | Hydraulic Slam |
| Rig Maneuvers | Stim Dodge | 1 | Servo Flurry |
| Rig Maneuvers | Breach Hammer | 2 | Kinetic Ram |
| Rig Maneuvers | Armor Piercer | 2 | Stim Dodge |
| Gem Surges | Thermal Burst | Free | Starting node |
| Gem Surges | Energy Siphon | 1 | Thermal Burst |
| Gem Surges | Cryo Lance | 1 | Thermal Burst |
| Gem Surges | Cryo Shield | 2 | Energy Siphon |
| Gem Surges | Cryo Stream | 2 | Cryo Lance |
| Gem Surges | Resonance Echo | 2 | Cryo Shield |
| Passive Augments | Blade Calibration | 1 | Starting branch node |
| Passive Augments | Cleaver Calibration | 1 | Starting branch node |
| Passive Augments | Mobility Augment | 1 | Blade Calibration |
| Passive Augments | Charge Recycler | 2 | Cleaver Calibration |
| Passive Augments | Stamina Recycler | 2 | Mobility Augment |
| Passive Augments | Thermal Overcharge | 2 | Charge Recycler |

The complete tree costs 24 points. The root actions still require their normal resources, and Gem Surges still require compatible sockets.

## Live passive effects

Blade Calibration adds 5% sword/blade/knife damage. Cleaver Calibration adds 5% axe/cleaver damage. These do not boost pistols or unclassified bashing weapons. Mobility Augment adds 5% movement speed. Stamina Recycler and Charge Recycler add 15% regeneration to their respective resources. Thermal Overcharge adds 10% Thermal weapon, surge and burn damage.

Saved passives apply on spawn, equipment refresh and live combat calculations. Resets remove them. Tree progression preserves the existing armor catalog, rarity rolls, sockets, resource costs and combat safety checks.

Validation covers the 18-node graph, prerequisites, purchases, save normalization, point boundaries/caps, repeated reset protection, live XP awards, locked remote inputs and all passive effects. The real UI is exercised with GUI/event doubles for desktop and portrait layouts, selecting locked nodes, unlocking, refunding and closing. A Roblox Studio playtest is still needed for final rendering and input delivery.
