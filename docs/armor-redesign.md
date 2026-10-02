# Saga Miners armor redesign

Implemented catalog: 75 armor items, with 25 per family. Each family has one Helmet, Chest, Gloves, Boots and Shield at every rarity. All players use Warrior; the equipped family defines the build. Old gear IDs, cosmetic rolls and sockets remain compatible, but legacy armor no longer appears in new drops.

| Family | Model | Helmet | Chest | Gloves | Boots | Shield | Matching weapon |
|---|---|---|---|---|---|---|---|
| Prospector | UtilityMiner | Health | Health | Power | Speed | Defense | Sword, MatrixSwords1–5 |
| Skirmisher | FrontierRanger | Speed | Power | Critical | Speed | Defense | Pistol, MatrixWeapons1–10 |
| Juggernaut | HeavyVanguard | Health | Health | Power | Health | Defense | Sword, MatrixSwords6–10 |

**A matching weapon counts as piece six.** Existing starter weapons without a family do not count. The highest unlocked set tier replaces lower tiers; different families can each activate a two-piece bonus.

| Rarity | Budget | Modifiers | Default drop weight |
|---|---:|---:|---:|
| Common | 10 | 0 | 40% |
| Uncommon | 15 | 0 | 25% |
| Rare | 22 | 1 | 20% |
| Ultra Rare | 30 | 2 | 10% |
| Legendary | 40 | 3 | 5% |

One purchased stat increment gives +5 HP, +1 Power or +1 Defense for one budget point; +0.5 Speed, +0.5% Critical or +0.5% Cooldown Reduction costs two budget points. Rare, Ultra Rare and Legendary reserve 6, 8 and 12 points respectively for randomly selected distinct modifiers. Remaining points go to the slot's primary stat. Odd primary budgets for Speed/Critical spend the leftover point on Power. Rolls persist and are not rerolled on login.

| Family | 2 pieces | 4 pieces | 6 pieces |
|---|---|---|---|
| Prospector | +10 HP, +1 Power | +20 HP, +2 Power, +5% CDR | +30 HP, +3 Power, +10% CDR, +5% healing received |
| Skirmisher | +0.5 Speed, +2% Critical | +1 Speed, +4% Critical, +5% CDR | +1.5 Speed, +8% Critical, +10% CDR, +10% damage after Dodge Roll |
| Juggernaut | +15 HP, +1 Defense | +25 HP, +2 Defense, +5% damage reduction | +40 HP, +4 Defense, +10% damage reduction, +15% threat |

Universal Dodge replaces the ability picker. Its damage window lasts three seconds, with a three-second base cooldown modified by armor. Threat influences enemy targeting while damage credit for loot stays separate. Healing received applies through the server healing entry point. Existing combat ceilings are 75% critical chance, 60% cooldown reduction and 20% combined passive damage reduction. See [the universal combat implementation](universal-combat.md) for PvP adjustments and gem integration.

| Depth | Common | Uncommon | Rare | Ultra Rare | Legendary |
|---|---:|---:|---:|---:|---:|
| 1–2 | 80% | 20% | 0% | 0% | 0% |
| 3–4 | 50% | 40% | 10% | 0% | 0% |
| 5–6 | 20% | 50% | 25% | 5% | 0% |
| 7–8 | 0% | 30% | 50% | 18% | 2% |
| 9+ | 0% | 10% | 40% | 40% | 10% |

Recovered armor first selects a slot, then rarity and a uniformly selected family. Owned items do not bias family or rarity odds. Recovering an item already at the available quality cap awards five coins per rarity tier; existing traits and enchants stay intact.

The visual system retains the miner, ranger and vanguard designs. All fifteen new helmets have distinct geometry, every armor slot gains details as rarity rises, and shields have family-specific utility grips, scout rails or reinforced vanguard plating.

Review every new armor asset in [the visual catalog](armor-review/index.html), or [the complete contact sheet](armor-review/all-75-armor.png). These renders use actual Luau geometry with a neutral cosmetic finish. Studio lighting and movement still need a live playtest.

Validation: equipment/save regressions, 2,250 exact point budgets, 100,000 depth drops, six-piece family bonuses, R6/R15 unique helmet geometry, expedition loot and trading regressions, and Rojo place build. No Roblox publication performed.
