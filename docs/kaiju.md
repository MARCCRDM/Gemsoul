# Mini kaiju

Knee-high monsters that follow you around the Outpost and fight on their
own, like the heroes in Heroes RNG: you run about and pull enemies in, and
your kaiju do the fighting while you fight beside them. You find new ones in
the wild and tame them, and in the arena two players' kaiju fight one on one,
for keeps.

They replace the critter pets in [pet-system-proposal.md](pet-system-proposal.md).

![The three kaiju in the four elements](kaiju/species.png)

## The three kinds

Each kind comes in Fire, Frost, Shock and Poison: twelve in all.

| Kind | Looks | Plays | Health | Damage | Speed |
| --- | --- | --- | --- | --- | --- |
| **Bulwark** | Stands upright: plated chest, fins down its back, a long tail | Slow, heavy blows, shrugs off 10% | 240 | 20 a blow, every 1.6 s | 12 |
| **Razorback** | Runs low: long toothed snout, spines, long legs | Quick light bites, fragile | 160 | 11 a bite, every 0.8 s | 20 |
| **Carapace** | Four stubby legs under a wide shell, a spiked club tail | The hardest to wear down: shrugs off 25% | 300 | 13 a blow, every 1.3 s | 10 |

Those are level 1. Each level adds 8% of them, up to level 30. A finer
Gemsoul (below) adds up to 20% more.

## The Gemsoul

Every kaiju carries a Gemsoul: a gem of its element, rolled like any gem
(rarity, Size, Clarity, Cut), with an E ability. The kaiju casts that E in
a fight every 9 seconds. The E is always one you can see land, never a dash
or a "while ready" bonus:

| Element | E abilities a Gemsoul rolls |
| --- | --- |
| Fire | Ember Lance, Supernova, Solar Flare, Flame Tornado |
| Frost | Cryo Lance, Absolute Zero, Hailstorm |
| Shock | Ion Spark, Chain Lightning, Thunder Pylon, Storm Call, Ion Cannon |
| Poison | Acid Spray, Toxic Cloud, Armor Melt, Toxic Tide, Maneater |

A Gemsoul you win is a gem like any other: socket it in your gear, enchant
it, sell it. Only its E works. Its Q and R lanes stay sealed, wherever it's
socketed.

## Your team

You start with one kaiju. A second slot opens when one of yours reaches
level 10, and a third at level 20. Phase 1 has one kaiju out at a time.

- **It fights on its own.** It goes for whatever you're fighting, or
  whatever comes at you.
- **Recall.** Calls it back to you; it stays out of the fight for 4 seconds.
  Use it when it's about to die, or about to kill a kaiju you want to tame.
- **Knocked out.** It goes back into its Gemsoul and is ready again after
  45 seconds.
- **Out of a fight** it heals 3% of its health a second.

## In the Outpost

### Wild kaiju

Up to three roam the Outpost at once, within two levels of the strongest
kaiju near them. One nobody fights burrows back after 10 minutes, and a new
one crawls out 90 seconds after one goes.

- **Kill it:** your kaiju gets 40 + 12 × its level EXP, and you get its
  Gemsoul.
- **Tame it:** it joins you, Gemsoul and all.

### Taming

Bring it to half its health or less **without killing it**, then try:

| Its health | Chance |
| --- | --- |
| 50% | 5% |
| 30% | 15% |
| 15% | 35% |
| 5% | 60% |
| 1 HP | nearly 80% |

Three failed tries and it burrows away. The tries are 2 seconds apart.

The hard part is not killing it. Every hit on a wild kaiju lands anywhere
from 60% to 140% of its usual damage, so one big hit can end the tame. To
hit gently, use its own element (it takes 75% from that); its weakness
element hits harder (125%). Recall your kaiju when it would finish the job.

### Moon bugs

Swarms of three to five little creatures. For now they're the brainrot
characters shrunk down: Tung Tung Tung Sahur, Tralalero Tralala, Brr Brr
Patapim and Bombardiro Crocodilo.
Kite them into your kaiju. Each is worth 10 EXP to your kaiju and 2 coins
to you, up to 300 coins a day.

## Feeding

A kaiju eats stones for EXP:

| Stone | EXP | In full until level |
| --- | --- | --- |
| Common | 20 | 10 |
| Uncommon | 45 | 15 |
| Rare | 100 | 20 |
| Ultra Rare | 220 | 25 |
| Legendary | 500 | always |

Past that level a stone gives half for ten levels, then a quarter, so a
common stone means little to a high-level kaiju. A stone of the element that
beats it gives half again; one of its own element gives a quarter more.

## The arena (phase 2)

One kaiju against one, two players. Every match is for keeps: the winner's
kaiju gets EXP and the winner takes the loser's Gemsoul. The losing kaiju
goes with it.

Proposed guardrails:
- A kaiju fights there from level 5, and only against kaiju within three
  levels of it.
- The same two players can't stake against each other again for six hours.
- You can't stake your last kaiju.

## Phases

1. **Phase 1:** one kaiju out at a time, wild kaiju, taming, moon bugs,
   feeding, recall.
2. **Phase 2:** the second and third slots, and the arena.

## In the code

| Where | What |
| --- | --- |
| `Shared.Kaiju` | The rules: kinds, stats, EXP, feeding, taming, the hit spread, slots, Gemsouls |
| `Shared.KaijuModels` | The models: `build(kind, element)`, `scale(model, s)` |
| `Shared.CreatureMotion` | Their walk (`Stride`), arms (`Arm`), jaw and tail |
| `Shared.GemTraits` | A Gemsoul's Q and R stay sealed (`traitsOf`) |
| `CreatureAnimation` (client) | Moves kaiju in `workspace.Kaiju` and wild ones in `workspace.Enemies` |

Tests: `tests/run_kaiju.py` checks the rules and builds every kind in every
element (joints, feet on the ground, part budget, motions).
