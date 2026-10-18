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

## The Gemsoul: one stone, three moves

Every kaiju carries a Gemsoul: a gem of its element, rolled like any gem
(rarity, Size, Clarity, Cut). All three of the kaiju's moves come from that
one stone, and they wake as it levels (`Kaiju.MoveLevels`):

| Key | Wakes at | What the kaiju does with it |
| --- | --- | --- |
| **E** | from the start | Its surge: 3 seconds into a fight, then at most every 9 seconds, after a wind-up its foe can see on its cast bar |
| **Q** | level 5 | Its strike: in place of a blow, every 7 seconds, named on its cast bar (1.6 of its blows, against the E's 2.6) |
| **R** | level 10 | Its defense: raised quickly when it's down to 60% health or a heavy blow or a cast is coming, at most every 14 seconds |

The moves are the player's own moves, and the ones a kaiju can cast: you
can see them land, never a dash or a "while ready" bonus
(`GemTraits.SoulMoves`):

| Element | Q (strike) | E (surge) | R (defense) |
| --- | --- | --- | --- |
| Thermal | Furnace Crescent, Magma Fault, Meteor Leap | Ember Lance, Supernova, Solar Flare, Flame Tornado | Heat Shield, Cauterize, Ring of Fire |
| Cryo | Glacier Fan, Permafrost Spire, Frost Chakram | Cryo Lance, Absolute Zero, Hailstorm | Ice Armor, Glacial Bulwark, Ice Pillar |
| Ion | Circuit Cleave, Thunder Dash, Skybreaker | Ion Spark, Chain Lightning, Thunder Pylon, Storm Call, Ion Cannon | Ion Shield, Capacitor, Tesla Fence |
| Corrosive | Caustic Dart, Vitriol Sweep, Toxic Flask | Acid Spray, Toxic Cloud, Armor Melt, Toxic Tide, Maneater | Rad Shield, Bio Regrowth, Toxic Mantle |

A kaiju's R is one of these (`Kaiju.AbilityPlans`):

- **A shell** (Heat Shield, Glacial Bulwark, Ice Pillar, Ion Shield,
  Capacitor, Rad Shield) soaks a share of its health in blows for a few
  seconds. Glacial Bulwark and Ice Pillar burst when the shell breaks or runs
  out, slowing everyone near. Heat Shield burns those near it every second.
  Capacitor brings its next Q and E 3 seconds nearer. Rad Shield cleanses it.
- **A ward** (Ice Armor, Toxic Mantle) cuts what it takes (Toxic Mantle
  poisons those near it, too).
- **A mend** (Cauterize, Bio Regrowth) heals it over a few seconds
  (Cauterize cleanses burns, poisons, slows and blinds first).
- **A ring** (Ring of Fire, Tesla Fence) hits everyone round it at once.

A Gemsoul you win is a gem like any other: socket it in your gear, enchant
it, sell it. In your gear all three of its moves work, like any gem's: its
Q in a sword, its E in a chest, its R in a shield. A Gemsoul saved before
this, its Q and R rolled from the whole lane, gets a kaiju's Q and R seeded
from its id (the same on every server and client); its E is kept.

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

Three kaiju fight beside you at once. You can keep 12; the others wait at
home. (The plan is a second slot when one of yours reaches level 10 and a
third at 20; the beta opens all three from the start: `Kaiju.SlotLevels`.)

![The starter roll: three kaiju, each landing on its card](kaiju/roll.png)

- **The starter roll.** Everyone starts with three kaiju, rolled like the
  gems in the intro: right after the move reveal, three cards spin through
  kaiju of every kind and element and land, one after another, on yours
  (a random kind in a random element, never the same pair twice, each with
  a Gemsoul rolled like a mined gem). Each card then shows its Gemsoul's
  rarity, what kind it is, and its moves: E ready now, Q at level 5, R at
  10. MEET YOUR TEAM brings them out (on its own after 20 seconds). The
  server makes the roll once and keeps it till it's claimed, so leaving
  doesn't reroll it. A player from before with fewer than three gets the
  rest rolled the same way, once, the next time they're in the Outpost; a
  roll left unclaimed is given anyway after 90 seconds there.
- **Your team** is the three out, in order: the first leads (the one a
  wild kaiju sees first, and the one some old screens show). Empty places
  fill on their own with your best at home (highest level, then oldest),
  so a knocked-out kaiju's place stays its own and the team is always full.
  Each walks in its own place round you: one to your right, one to your
  left, one behind.
- **They fight on their own.** They take on any moon bug within 28 studs of
  you, going first for one that's after you or them. They only fight a
  wild kaiju once you've started a fight with that one (see
  [Wild kaiju](#wild-kaiju)). They follow you everywhere in the Outpost (put
  back beside you if one falls far behind) and go away in a fight, a match
  or an expedition.
- **EXP** goes to each of them out: for kills and for the rocks you mine.
- **Recall.** Calls all of them back to you; they stay out of the fight for
  4 seconds. Use it when one's about to die, or about to kill a kaiju you
  want to tame.
- **Knocked out.** That one goes back into its Gemsoul and is ready again
  after 45 seconds; the others fight on.
- **Out of a fight** they heal 3% of their health a second.
- **Changing the team** (the panel): LEAD puts one at the front; SEND OUT
  puts one from home in place of one of the team. Not one that's fought in
  the last 3 seconds, and not twice in a moment.

## On screen

![The team strip on a phone, and the kaiju panel](kaiju/hud.png)

On a computer the strip sits at the bottom left, TAME above it:
[the lobby on a computer](kaiju/hud-desktop.png).

- **The team strip:** a tile for each of your team, the lead first (edged in
  gold): its portrait, level and health, and three dots down its right edge
  for Q, E and R, lit when the move is ready, faint while it recharges and
  hollow while it's still asleep. Knocked out, its tile says when it's back
  (KO 32s). On a computer it sits at the bottom left; on a phone under your
  level and coins, and at the top right while you hunt. Tap a tile for the
  kaiju panel on that kaiju.
  - **RECALL** brings them all back to you.
  - **HUNT** takes your combat kit out to fight beside them (STOP, or 1, puts
    it away).
- **TAME**, beside the strip, when a wild kaiju near you is down to half its
  health: the chance right now and the tries left. It starts the taming
  cast (see Taming), and hides while the cast is under way.
- **The kaiju panel:** on the left every kaiju you have: YOUR TEAM (numbered,
  1 leads; health, EXP, KO and when it's back) and AT HOME. Pick one for it
  in full on the right: its portrait, kind, level, its Gemsoul's rarity,
  health, damage and speed, its EXP, and its E, Q and R with what each does
  (READY, or WAKES AT LV 5 / 10). Under that, what you can do: **LEAD** (one
  of the team to the front), **SEND OUT** (one from home: then pick which of
  the team it goes out in place of) and **FEED**: tick stones from your
  pouch for that kaiju, each showing the EXP it gives it.
- **The Gem Vault** shows a Gemsoul's branches as the moves a kaiju casts,
  with KAIJU LV 5 by Q and KAIJU LV 10 by R.

## Hunting

Your kaiju fights whether or not you do. To fight yourself, press HUNT: your
combat kit comes out, as in a spar but alone. Only creatures can hit you, and
you can only hit creatures; a creature's finishing blow knocks you down for a
few seconds, as in a spar. Wild kaiju leave you and your kaiju alone until
you start a fight with one. Moon bugs don't: out past the core
they come through rifts at miners too ([frontier.md](frontier.md)), and
their finishing blow knocks you down the same way.

## In the Outpost

Wild kaiju roam the frontier, out past the Outpost's core and at least 140
studs from the landing pad. Moon bugs come through rifts round players out
past the core.

### Wild kaiju

Up to four roam the Outpost at once, in **packs of two** of a kind (each
its own element; the two packs are different kinds). They're within two
levels of the strongest kaiju near them, with half again the health of a
kaiju of yours at their level: it takes you and your kaiju together. They
stand about your height (yours come up to your knee). A fifth guards a Rift
Vein (see [The vein guardian](#the-vein-guardian)). Their names show from
160 studs off.

They go about their day:

- Each pack has a **den** out in the frontier, clear of the rocks, the
  buildings, the old workings, the ramps and the vein sites, at least 110
  studs from the other pack's.
- Each kaiju wanders round its den (up to 34 studs), ambling at under half
  its speed, and stops to do things: **sniff** the ground (head down),
  **look about**, **lie down** for 8 to 16 seconds, or **roar**. Walking
  takes up about half its time, lying down about a quarter. The second of a
  pair keeps near the first, and gets up to follow when it wanders off.
- Every one to two minutes the den moves on 20 to 30 studs, roughly the way
  it was going, so a pack wanders about 150 studs across the quarry in ten
  minutes and you'll meet it somewhere new.
- Come within 22 studs and it stops to look you over, turning to face you.
  Now and then (at most every 25 seconds) it roars at you, each kind in its
  own voice: a deep bellow, a raspy snarl, a rumble under a hiss. Either way
  it leaves you be.
- It doesn't wander into the core, and it only sets off where the way is
  clear (nothing solid in a line to where it's going), so it doesn't push
  against masts or containers.
- One within 220 studs but off your screen gets an arrow at the screen's
  edge, with how far it is (the guardian's in red), so you can go and find
  them.

Your own kaiju does the same, in a small way. Stand still for 3 seconds and
it potters round you (within 6 studs): sniffs, looks about, lies down. It's
up and after you as soon as you move on.

A wild kaiju leaves you and your kaiju alone until you start a fight with
it. There are two ways:

- **Challenge it:** hold **E** beside it (within 20 studs), with your kaiju
  out or while you hunt. Your kaiju goes in.
- **Hit it** while you hunt.

Then it fights everyone who started on it, and their kaiju. **Its packmate
joins in** if it's within 40 studs: start on one of a pair and you'll often
face both. It doesn't go for anyone else near. It fights as above (its E too), and only hits you
while you hunt. Lead it more than 70 studs from its den and it walks back to
heal. Once it has been back 8 seconds with nobody fighting it, it forgets who
started on it, and goes about its day again.

One nobody fights burrows back after 7 to 15 minutes (each its own time, so
they don't all go at once and leave the quarry empty, as they used to every
ten minutes). Another comes up elsewhere 20 seconds after one burrows, 90
seconds after one is killed or tamed. One that falls through the floor is
put back at its den.

- **Kill it:** every kaiju that fought it gets 40 + 12 × its level EXP, and
  the player who (with their kaiju) did the most gets its Gemsoul.
- **Tame it:** it joins you, Gemsoul and all, at its level.

### The vein guardian

One of the three Rift Veins is guarded (its rocks are red-tinted and
luckier still, +110%, and its beam is red: see [frontier.md](frontier.md)).
A wild kaiju of level 16 to 20 keeps a short beat in front of it, a head
taller than you. It loses narrowly to a level-25 kaiju or to two level-10s,
and beats a kaiju of its own level.

- It paces up and down in front of its vein, sniffs about and naps (about
  half the time). It looks over anyone who comes close, and roars at them
  now and then. It doesn't attack them.
- The first swing at its vein's rocks stirs it (it looks round at you), the
  second makes it roar, and the **third swing** wakes it (two swings, then
  nothing for 30 seconds, and the count
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

Bring it to half its health or less **without killing it**. When it's
ready to be caught, it **glows gold** (a pulsing outline you can see
through rocks) with **READY TO TAME** and the chance over it. Anyone within
140 studs sees that.

Then tap **TAME**. Taming is a **cast** of 2.5 seconds (`Kaiju.Tame`):

- A beam of gold light runs from your hand to it, and motes of light
  spiral in round it, closing in as the cast goes on. Everyone near sees
  this.
- It's **held**: it stops where it is and struggles against the hold
  (crouched, twisting, jaws snapping: the `Bound` pose). It can't move,
  fight back or be hurt, and your kaiju (anyone's) leaves it alone.
- Your **cast bar** says TAMING and what it is, with the chance, and fills
  as it goes: "Stay close and don't get hit."
- The cast **breaks** if you're hit (by a critter, say), if you stray more
  than 38 studs from it, or if you leave the Outpost. A broken cast costs
  no try.
- At the end comes the roll, at its health then:

| Its health | Chance |
| --- | --- |
| 50% | 5% |
| 30% | 15% |
| 15% | 35% |
| 5% | 60% |
| 1 HP | nearly 80% |

The bar ends on the result: **TAMED!** (it's yours, in the kaiju panel),
**IT BROKE FREE** (a try spent), **IT FLED** (it burrowed away after the
third) or **TAME BROKEN** (cut short). You start a cast from within 30
studs; tries are at least 2 seconds apart, and you tame one at a time
(and nobody else can tame one you're holding).

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

**A critter goes for a kaiju before a player.** If a kaiju is out within 30
studs of it, it goes for that kaiju, your own before anyone else's, and your
kaiju goes for it. So your kaiju draws the critters off you while you mine.
Recall it and they come back for you.

Their level comes from where they came through: 1 to 4 in the Fringe, 9 to
13 at the Edge (tougher again: a quarter more health, a fifth more damage).
Each one gives every kaiju that fought it 6 + 2 per level EXP (half again
from the Edge; a quarter after your first 60 of the day), and whoever did
the most to it 2 coins from the Fringe or 4 from the Edge, up to 300 a day.
A kaiju left at home earns nothing from them.

## Levelling while you mine

Your kaiju out beside you levels while you mine. Every rock you break gives
it a little EXP, by the rock's size (`Kaiju.MineExp`: a Regolith Chunk 5, a
Crystal Boulder 8, a Monolith 12, a Geode 20). It also fights the critters
your swings bring out past the core, which gives more. A full free charge
(600 swings, about 130 rocks) is worth about 800 EXP from the rocks alone,
a few levels for a young kaiju, before the critters and before feeding it
the Commons you mined. A kaiju that's down, or left at home, earns nothing
(`KaijuServer.mined`, from `OutpostServer.onRockMined`).

## Feeding

A kaiju eats stones for EXP, up to 25 at a time (`Kaiju.FeedBatch`). Mining
pays mostly Commons, so `PICK COMMONS` in its feed tab picks 25 spare ones
(loose, and not named by a saved loadout) in one tap:

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

1. **Phase 1 (in the game now):** three kaiju out at once (the beta opens
   all three slots) from the starter roll, wild kaiju, taming, moon bugs,
   feeding, recall, hunting.
2. **Phase 2:** slots opening with level (10, then 20), and the arena.

`Config.Features.Kaiju` turns all of it off.

## In the code

| Where | What |
| --- | --- |
| `Shared.Kaiju` | The rules: kinds, stats, EXP, feeding, taming, the hit spread, slots, Gemsouls and the levels their moves wake at (`MoveLevels`, `move`, `moves`), how each move lands (`AbilityPlans`), the roster, sizes (`Scale`), packs and a wild one's day (`Wild`, `Roam`, `mood`) |
| `Shared.KaijuFight` | How they fight: each kind's blows and timings, guard, parry and hops (`resolve`), what a foe reads off one, the brain's view |
| `Shared.KaijuModels` | The models: `build(kind, element)`, `scale(model, s)`; the trunk on a `Body` joint |
| `Shared.CreatureMotion` | Their walk (`Stride`), arms (`Arm`), jaw and tail, and every fight pose (`fight`, `apply`) |
| `Shared.GemTraits` | The moves a Gemsoul rolls (`SoulMoves`); an old one's seeded into them (`traitsOf`) |
| `Shared.Spar` | `Spar.hunting`: the kit out alone |
| `KaijuFighter` | A kaiju in a fight (yours or a wild one): reads its foe, asks the brain, winds up, strikes, guards, hops, casts its E, its Q in place of a blow and its R when hard pressed (`setMoves` after a level); the attributes clients pose it by |
| `KaijuServer` | Your team: the starter roll (`KaijuRoll`, `KaijuRollClaim`, kept in the profile's `KaijuRoll` till claimed; `KaijuRolled` once it is), the team out and back, each in its place (`KaijuSlot` on the model), following (pottering round you when you stand about) and fighting, hurt by element and its guard, knockout (`KaijuDown_<id>` on you), recall, the team and its lead (`KaijuTeam`, `KaijuActive`), feeding any of yours (`KaijuFeed`), EXP for the rocks you mine (`mined`); `all()`, `team(player)`, `pets()` (each player's lead) for the rest of the server |
| `KaijuWilds` | Wild kaiju in packs (dens, wandering, moods, `KaijuMood` on the model), the vein guardian (`veinSwing`, `veinMoved`) and moon bugs: spawning (`spawnBug`: one out of a rift at its band's level, at its prey, or roaming a wandering rift), their brain, slipping back through a rift, their pay, the pick's `bonk`, the spread on blows (`TakenScale`, applied by `Enemies.damage`), kills, taming (`KaijuTame`), who started a fight with each (`KaijuChallenge`, its Challenge prompt, or a hit) |
| `FrontierServer` | Where and when rifts open and moon bugs come through ([frontier.md](frontier.md)) |
| `KaijuAbilities` | Every move a kaiju casts: where it lands, on whom, and its look; its R's shell, ward or mend (`soak`, applied by `KaijuServer.hurt` and, through `Soak`, `Enemies.damage`) |
| `SparServer` | `Hunt`: the kit out alone |
| `KaijuHud` (client) | The team strip, RECALL, HUNT, TAME, a wild kaiju's Challenge, the kaiju panel, and the roll in the Outpost for a player still owed one |
| `KaijuRoll` (client) | The starter roll's screen: in the intro after the move reveal (`Intro.client`), and in the Outpost (`KaijuHud`) |
| `KaijuTaming` (client) | The gold glow and READY TO TAME on a kaiju that can be caught, the tame's beam and motes (from `KaijuTameBy`, for everyone), the tamer's cast bar and its result (`TameResult`) |
| `CreatureAnimation` (client) | Moves kaiju in `workspace.Kaiju` and wild ones in `workspace.Enemies`: their walk, their fight poses and their moods (`KaijuMood`: `CreatureMotion.Moods`) |

Tests: `tests/run_kaiju.py` checks the rules (your team's order, filling
and size, the roll owed and its picks never repeating a kind and element)
and how they fight (each
kind's style, guard, parry, breaks, hops, reads, the brain's choices),
builds every kind in every element (joints, feet on the ground, part
budget, motions, every fight pose), and runs the server against stand-ins:
the starter roll (three, the same when asked again, nothing out before the
claim, three out in their places after, never twice, and given anyway after
a while in the Outpost), your team (three out, one knocked out leaving the
others, recall and EXP for all of them, LEAD, SEND OUT, the checks on a new
team, feeding one at home), every move lands where it should (an R's shell, ward, mend, aura and
burst too), your kaiju's moves follow its level, its Q goes off in place of
a blow and waits its turn, its R goes up when it's hard pressed (not
before), a shell soaks blows till it breaks and a ward takes its share, on
your kaiju and a wild one, your kaiju comes out, fights with wind-ups,
is hurt by element, knocked out and back, recalled, switched and fed, wild
kaiju take the spread and pick their foes. A wild kaiju leaves a miner, a
hunter and your kaiju alone till someone challenges or hits it, and forgets
them once home; your kaiju (and its E) leaves it be till then. Heavies break
guards, parries leave the attacker reeling, a wild kaiju hops from a
hunter's charged heavy, the E winds up on the cast bar, a whole duel
between two kaiju, kills pay their Gemsoul and EXP, taming (range, half
health, the cast holding it untouchable and still, breaking when you stray
or are hit without spending a try, your kaiju leaving it be, the roll at
the end, tries, burrowing, a full roster), moon bugs' coins and daily cap,
and the rifts: who they open round, the caps, a bug hopping out at its prey
(a miner too), giving up and slipping back. The vein guardian: its level,
health and where it sleeps, waking on the third swing at its own vein
(not another's), going for a plain miner, everyone mining its vein once
awake, not burrowing of old age, back to sleep, moving with its vein, and
its coins, with no new one until the vein moves. A wild kaiju's day: ten
simulated minutes in which each one walks and stops to sniff, look, rest or
roar, keeps to its range and out of the core and keep-out zones, keeps near
its packmate, while the dens move on; the guardian paces and naps; stopping
to look at someone close and leaving them be; your kaiju pottering round you
and following when you move. A packmate close by joining in when you
start on its mate (not one far off), and a wild kaiju never walking into a
wall. A critter going for your kaiju rather than you, your kaiju going for
it, the bites landing on the kaiju; recall it and the critter comes back to
you, and another miner's critter is drawn by your kaiju too. A rock mined
with it out gives it EXP by the rock's size (none while it's down), and a
long session's rocks make a young kaiju a few levels. The Outpost for
fifteen minutes: a miner at
the Edge drawing critters while the wild kaiju roam and their lifetimes run
out; no brain errors, the critters within their caps, never a moment
without wild kaiju (the old fixed lifetimes left the quarry empty for 90
seconds every ten minutes), and nothing piling up.
The rules also check every Gemsoul's three moves (a kaiju's own, waking at
5 and 10), every move's plan, an old Gemsoul's seeded Q and R, and each
key's power. `tests/kaiju_models_cases.luau` checks each mood's pose (a held kaiju
crouches and struggles). `tests/run_kaiju_taming.py` drives the taming
screen: a weakened kaiju near you glows with READY TO TAME and its chance (a
healthy one, a far one, one being tamed or one out of the Outpost doesn't),
the glow pulses, a cast draws two beams from your hand and twelve motes
that close in, the bar fills, and it ends on TAMED! or TAME BROKEN and
goes.
`tests/run_spar.py` covers hunting, and `tests/run_mobile_layout.py` the
card's place on every phone.
