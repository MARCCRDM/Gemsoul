# Mini kaiju

Small monsters that follow you around the Outpost and fight on their
own, like the heroes in Heroes RNG: you run about and pull enemies in, and
your kaiju do the fighting while you fight beside them. You find new ones in
the wild and tame them, and in the arena two players' kaiju fight one on one,
for keeps.

They replace the critter pets in [pet-system-proposal.md](pet-system-proposal.md).

![The three kaiju in the four elements](kaiju/species.png)

## The three kinds

Each kind comes in Thermal, Cryo, Ion and Corrosive: twelve in all.

| Kind | Looks | Plays | Health | Damage | Speed |
| --- | --- | --- | --- | --- | --- |
| **Bulwark** | Stands upright: plated chest, fins down its back, a long tail | Slow, heavy blows, shrugs off 10% | 240 | 20 a blow; attacks about every 1.6 s | 12 |
| **Razorback** | Runs low: long toothed snout, spines, long legs | Quick light bites, fragile | 160 | 11 a bite; attacks about every 0.8 s | 20 |
| **Carapace** | Four stubby legs under a wide shell, a spiked club tail | The hardest to wear down: shrugs off 25% | 300 | 13 a blow; attacks about every 1.3 s | 10 |

Those are level 1. Each level adds 8% of them, up to level 30. A finer
Gemsoul (below) adds up to 20% more.

## The Gemsoul

Every kaiju carries a Gemsoul: a gem of its element, rolled like any gem
(rarity, Size, Clarity, Cut), with an E ability. The kaiju casts that E in
a fight 3 seconds in and then at most every 9 seconds, after a wind-up its
foe can see on its cast bar. The E is always one you can see land, never a
dash or a "while ready" bonus:

| Element | E abilities a Gemsoul rolls |
| --- | --- |
| Thermal | Ember Lance, Supernova, Solar Flare, Flame Tornado |
| Cryo | Cryo Lance, Absolute Zero, Hailstorm |
| Ion | Ion Spark, Chain Lightning, Thunder Pylon, Storm Call, Ion Cannon |
| Corrosive | Acid Spray, Toxic Cloud, Armor Melt, Toxic Tide, Maneater |

A Gemsoul you win is a gem like any other: socket it in your gear, enchant
it, sell it. Only its E works. Its Q and R lanes stay sealed, wherever it's
socketed.

## How they fight

Kaiju fight exactly as the Arena's rival does, run by the same brain
(`Shared.DuelistBrain`), just shrunk to their size and in their own blows.
They read their foe the way the rival reads you: a swing coming, a charged
heavy, a cast, a raised guard, an opening after a blow, a foe standing idle.

| | Quick blow (combos) | Heavy (breaks a guard) | Guard |
| --- | --- | --- | --- |
| **Bulwark** | Claw Swipe, up to 2 in a row | Ground Stomp: 2× | arms up, takes 30% |
| **Razorback** | Bite, up to 3 in a row | Tail Lash: 1.6× | a low crouch, takes 40% |
| **Carapace** | Shell Snap, up to 2 in a row | Shell Slam: 1.8× | into its shell, takes 15% |

- **Wind-ups.** Every blow winds up first (the brute slowest, the runner
  quickest). A heavy rings its feet in orange and names itself on the cast
  bar: hop out of it. The third blow of a combo lands 30% harder.
- **Guard and parry.** A guard takes most of a blow. A light blow landing
  just as a guard goes up (within 0.22 s) is parried, and the attacker reels
  for 0.45 s; a guard parries at most every 1.5 s. A heavy smashes through a
  guard, staggers it, and the guard can't go up again for 0.9 s.
- **Hops, pounces, counters.** A kaiju hops aside from a heavy or a cast
  (untouchable for 0.3 s), pounces on a foe that keeps out of reach, counters
  a blow it just blocked or a foe left open after swinging, circles between
  blows and backs off when badly hurt.
- **Hunting a wild kaiju yourself.** Your swings meet its guard as they
  would the rival's: your heavy breaks it, a light swing just as it braces
  is parried (and you reel), and it hops away from your charged heavy.

![Each kind's fight poses](kaiju/fight-poses.png)

Distances are scaled: the brain thinks in the rival's studs, a kaiju's
reach is its kind's at its size (a kaiju of yours is 0.55 the size of the
model, a wild one 0.75), and its steps, hops and pounces shrink to match.

## Your team

Your first visit to the Outpost brings you a kaiju: a random kind in a
random element. A second slot opens when one of yours reaches level 10, and
a third at level 20. Phase 1 has one kaiju out at a time; you can keep 12.

- **It fights on its own.** It takes on any moon bug within 28 studs of
  you, going first for one that's after you or it. It only fights a wild
  kaiju once you've started a fight with that one (see
  [Wild kaiju](#wild-kaiju)). It follows
  you everywhere in the Outpost (put back beside you if it falls far behind)
  and goes away in a fight, a match or an expedition.
- **Recall.** Calls it back to you; it stays out of the fight for 4 seconds.
  Use it when it's about to die, or about to kill a kaiju you want to tame.
- **Knocked out.** It goes back into its Gemsoul and is ready again after
  45 seconds.
- **Out of a fight** it heals 3% of its health a second.

## On screen

![The kaiju card on a phone, the hunt, and the kaiju panel](kaiju/hud.png)

On a computer the card sits at the bottom left, TAME above it:
[the lobby on a computer](kaiju/hud-desktop.png).

- **The kaiju card:** its portrait, its kind (in its element's colour), level,
  health and EXP, and its
  E (the chip on the portrait fills as it readies). On a computer it sits at
  the bottom left; on a phone under your level and coins, and at the top
  right while you hunt. Tap it for the kaiju panel.
  - **RECALL** brings it back to you.
  - **HUNT** takes your combat kit out to fight beside it (STOP, or 1, puts
    it away).
  - Knocked out, the card says when it's back.
- **TAME**, beside the card, when a wild kaiju near you is down to half its
  health: the chance right now and the tries left.
- **The kaiju panel:** the one out (stats, its Gemsoul and E), your others
  (SEND OUT to swap), and FEED: tick stones from your pouch, each showing the
  EXP it gives.
- **The Gem Vault** shows a Gemsoul's Q and R branches as sealed.

## Hunting

Your kaiju fights whether or not you do. To fight yourself, press HUNT: your
combat kit comes out, as in a spar but alone. Only creatures can hit you, and
you can only hit creatures; a creature's finishing blow knocks you down for a
few seconds, as in a spar. Wild kaiju leave you and your kaiju alone until
you start a fight with one. Moon bugs don't: out past the core
they come through rifts at miners too ([frontier.md](frontier.md)), and
their finishing blow knocks you down the same way.

## In the Outpost

Wild kaiju live in the far quarry, at least 140 studs from the landing pad.
Moon bugs come through rifts round players out past the core.

### Wild kaiju

Up to two roam the Outpost at once, within two levels of the strongest
kaiju near them, with half again the health of a kaiju of yours at their
level: it takes you and your kaiju together. A third guards a Rift Vein
(see [The vein guardian](#the-vein-guardian)).

A wild kaiju leaves you and your kaiju alone until you start a fight with
it. There are two ways:

- **Challenge it:** hold **E** beside it (within 20 studs), with your kaiju
  out or while you hunt. Your kaiju goes in.
- **Hit it** while you hunt.

Then it fights everyone who started on it, and their kaiju. It doesn't go
for anyone else near. It fights as above (its E too), and only hits you
while you hunt. Lead it more than 70 studs from home and it walks back to
heal. Once it has been home 8 seconds with nobody fighting it, it forgets who
started on it, and it's calm again.

One nobody fights burrows back after 10 minutes. A new one crawls out 90
seconds after one goes.

- **Kill it:** every kaiju that fought it gets 40 + 12 × its level EXP, and
  the player who (with their kaiju) did the most gets its Gemsoul.
- **Tame it:** it joins you, Gemsoul and all, at its level.

### The vein guardian

One of the three Rift Veins is guarded (its rocks are red-tinted and
luckier still, +110%, and its beam is red: see [frontier.md](frontier.md)).
A wild kaiju of level 16 to 20 sleeps in front of it. It loses narrowly to
a level-25 kaiju or to two level-10s, and beats a kaiju of its own level.

- It sleeps through people walking by. The **third swing** at its vein's
  rocks wakes it (two swings, then nothing for 30 seconds, and the count
  starts again).
- Awake, it goes for whoever woke it, and anyone else who mines its vein,
  **a plain miner too**, not only hunters. Its finishing blow knocks a
  miner down rather than killing them. And it fights their kaiju.
- Challenge it, fight it or tame it like any other wild kaiju. Killed, it
  also pays **40 coins** (within the 300 a day from critters).
- Lead it 70 studs from home and it walks back. Home 8 seconds with
  nobody fighting it, it forgets everyone and goes back to sleep: three
  swings again.
- It never burrows of old age. Beat it or tame it and the vein is yours
  until the vein moves on; then a fresh guardian sleeps at the new site. If
  the vein moves while its guardian is still about, the guardian goes with
  it.

### Taming

Bring it to half its health or less **without killing it**, then try:

| Its health | Chance |
| --- | --- |
| 50% | 5% |
| 30% | 15% |
| 15% | 35% |
| 5% | 60% |
| 1 HP | nearly 80% |

Three failed tries and it burrows away. The tries are 2 seconds apart, from
within 30 studs.

The hard part is not killing it. Every hit on a wild kaiju lands anywhere
from 60% to 140% of its usual damage, so one big hit can end the tame. To
hit gently, use its own element (it takes 75% from that); its weakness
element hits harder (125%). Recall your kaiju when it would finish the job.

### Moon bugs

Little creatures that tear through reality at you: each comes through a
rift of its own, a ragged tear in the air that crackles for a second and a
half, lets it hop out at you, and seals. Mining out past the Outpost's core
draws them (about 1 in 35 swings in the Fringe, 1 in 17 at the Edge), and
now and then the frontier tears open by itself and a few roam round it; see
[frontier.md](frontier.md). For now they're the brainrot characters shrunk
down: Tung Tung Tung Sahur, Tralalero Tralala, Brr Brr Patapim and
Bombardiro Crocodilo.
They're built light (no armour, nothing too small to see at their size),
since a dozen can be about at once. Let your kaiju fight them, bonk them
with your pick, hunt them, or run back to the core, where they give up and
slip back through rifts of their own.

Their level comes from where they came through: 1 to 4 in the Fringe, 9 to
13 at the Edge (tougher again: a quarter more health, a fifth more damage).
Each one gives every kaiju that fought it 6 + 2 per level EXP (half again
from the Edge; a quarter after your first 60 of the day), and whoever did
the most to it 2 coins from the Fringe or 4 from the Edge, up to 300 a day.
A kaiju left at home earns nothing from them.

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

1. **Phase 1 (in the game now):** one kaiju out at a time, wild kaiju,
   taming, moon bugs, feeding, recall, hunting.
2. **Phase 2:** the second and third slots, and the arena.

`Config.Features.Kaiju` turns all of it off.

## In the code

| Where | What |
| --- | --- |
| `Shared.Kaiju` | The rules: kinds, stats, EXP, feeding, taming, the hit spread, slots, Gemsouls, each E's plan, the roster |
| `Shared.KaijuFight` | How they fight: each kind's blows and timings, guard, parry and hops (`resolve`), what a foe reads off one, the brain's view |
| `Shared.KaijuModels` | The models: `build(kind, element)`, `scale(model, s)`; the trunk on a `Body` joint |
| `Shared.CreatureMotion` | Their walk (`Stride`), arms (`Arm`), jaw and tail, and every fight pose (`fight`, `apply`) |
| `Shared.GemTraits` | A Gemsoul's Q and R stay sealed (`traitsOf`) |
| `Shared.Spar` | `Spar.hunting`: the kit out alone |
| `KaijuFighter` | A kaiju in a fight (yours or a wild one): reads its foe, asks the brain, winds up, strikes, guards, hops, casts its E; the attributes clients pose it by |
| `KaijuServer` | Your kaiju: the starter, out and back, following and fighting, hurt by element and its guard, knockout, recall, switching, feeding (`KaijuRecall`, `KaijuActive`, `KaijuFeed`) |
| `KaijuWilds` | Wild kaiju, the vein guardian (`veinSwing`, `veinMoved`) and moon bugs: spawning (`spawnBug`: one out of a rift at its band's level, at its prey, or roaming a wandering rift), their brain, slipping back through a rift, their pay, the pick's `bonk`, the spread on blows (`TakenScale`, applied by `Enemies.damage`), kills, taming (`KaijuTame`), who started a fight with each (`KaijuChallenge`, its Challenge prompt, or a hit) |
| `FrontierServer` | Where and when rifts open and moon bugs come through ([frontier.md](frontier.md)) |
| `KaijuAbilities` | Every E a kaiju casts: where it lands, on whom, and its look |
| `SparServer` | `Hunt`: the kit out alone |
| `KaijuHud` (client) | The card, RECALL, HUNT, TAME, a wild kaiju's Challenge and the kaiju panel |
| `CreatureAnimation` (client) | Moves kaiju in `workspace.Kaiju` and wild ones in `workspace.Enemies`: their walk and their fight poses |

Tests: `tests/run_kaiju.py` checks the rules and how they fight (each
kind's style, guard, parry, breaks, hops, reads, the brain's choices),
builds every kind in every element (joints, feet on the ground, part
budget, motions, every fight pose), and runs the server against stand-ins:
every E lands where it should, your kaiju comes out, fights with wind-ups,
is hurt by element, knocked out and back, recalled, switched and fed, wild
kaiju take the spread and pick their foes. A wild kaiju leaves a miner, a
hunter and your kaiju alone till someone challenges or hits it, and forgets
them once home; your kaiju (and its E) leaves it be till then. Heavies break
guards, parries leave the attacker reeling, a wild kaiju hops from a
hunter's charged heavy, the E winds up on the cast bar, a whole duel
between two kaiju, kills pay their Gemsoul and EXP, taming (range, half
health, tries, burrowing, a full roster), moon bugs' coins and daily cap,
and the rifts: who they open round, the caps, a bug hopping out at its prey
(a miner too), giving up and slipping back. The vein guardian: its level,
health and where it sleeps, waking on the third swing at its own vein
(not another's), going for a plain miner, everyone mining its vein once
awake, not burrowing of old age, back to sleep, moving with its vein, and
its coins, with no new one until the vein moves.
`tests/run_spar.py` covers hunting, and `tests/run_mobile_layout.py` the
card's place on every phone.
