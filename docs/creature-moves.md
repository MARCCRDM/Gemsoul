# Creature moves: the critters' and bosses' own attacks

In dungeons and the Rift, the brainrot fighters used to fight with the
same rig maneuvers as a player (Hydraulic Slam, Breach Hammer, Servo
Flurry...). Now each one has moves of its own:

- **Room fighters** (Sahur, Tralalero, Patapim, Crocodilo) have their
  signature move, the one their Outpost critter already had, beside two rig
  maneuvers.
- **Bosses** have three moves of their own. One of them is a big
  telegraphed attack.

The moves are data in `Shared.CreatureMoves`. `DungeonRules` lists a
fighter's three moves by id, as it lists rig maneuvers. The Rift's boss is a
`DungeonRules.Bosses` fighter, so it has the same moves.

## How a move lands

Each move has a shape:

| Shape | What it does |
| --- | --- |
| Strike | Blows in reach. A combo hits several times. Its last blow can be heavy, which breaks a raised guard. A tongue, a lash or a branch reaches further. |
| Slam | Brought down round its own feet. The closer you are, the harder it hits, with a stun at the core and a stagger in the middle. |
| Roar | Round its own feet. It does little damage, but its effects land through a raised guard. |
| Blast | A ring where you stood as it started. |
| Bombs | Several rings round you: the first where you stood, the rest scattered. Each one hits once. |
| Leap | A jump onto where you stood as it crouched, landing as a slam. |
| Dash | A charge straight through you, hitting anyone along its path. |
| Cone | A breath: everyone in front of it, within its reach and its angle, as it faced when it started. Two rings down the cone show it. |
| Dive | A leap whose landing is a slam, with bombs scattered round the crater. |
| Wave | A ring that rolls out from its feet. It hits everyone between its core and its edge: right beside it and out past the edge are the only safe places. The core is marked. |
| Pull | Everyone within its ring is dragged to its feet and hit. Where it stood stays poisoned. |
| Hops | A leap that lands and leaps again, three times, each onto where you stand then. |
| Trail | A charge down a path fixed as it crouched (rings show it), leaving harmful ground along it. |
| Line | The same path, erupting from its feet while it stays put. |
| Aura | A storm round it: a burst, then a hit every second on everyone near it, wherever it walks, for six seconds. |
| Fan | Five paths spread out ahead of it, each shown by rings. Anyone on any of them is hit. |

A ring shows where every ring lands, and rings along every path and down
every cone, for the whole wind-up. Step out of them. A Leap aims at where
you stood when it started, so moving away is enough; a Hops boss leaps
again at where you are, so keep moving.

Area moves hit **everyone in the fight** who's inside the ring, not just
the player the boss is on. Kaiju are not hit by these moves yet.

What a move can leave on you:

| Effect | What it does |
| --- | --- |
| Burn | A share of its hit every second |
| Poison | A share of its hit every second, and your healing is cut |
| Slow | You move slower |
| Stun | You can't act. A frost boss's stun shows as **Frozen**, a shock boss's as **Shocked** |
| Blind | Some of your blows miss |
| Sunder | Your armour is shredded |

A guard keeps these effects off you, except a Roar's. Some moves leave
harmful ground behind (a cloud), which keeps ticking for a few seconds.

**The big attack.** Each boss's big attack has a wind-up of 1.4 to 1.6
seconds, a wide ring (or a path, or a cone) and a 15 second cooldown. It
never comes in the first 6 seconds of a fight. When it starts, everyone in
the fight is told what to do: "*Boss* winds up *move*! Get out of the
ring!", or for the moves that need something else, "Get in close or far
out!", "Get out of its reach!", "Keep moving: it bounces three times!",
"Get off its path!" or "Keep away from it!".

## When it uses them

`DuelistBrain.pickMove` reaches for a creature move whenever one is off
cooldown and its foe is within that move's reach. It uses one even when it
was about to walk or circle. The big attack comes first.

- It doesn't use one in the middle of a dodge.
- From behind its guard, it uses one only now and then.
- It doesn't use one until it's free to attack again after its last blow.
- A room fighter still swaps a heavy blow for one of its rig maneuvers
  when its signature move is on cooldown.

## Room fighters

| Fighter | Signature move | Shape | What it does | Beside it |
| --- | --- | --- | --- | --- |
| Tung Tung Tung Sahur | Bat Slam | Slam, 7 studs | 220%, breaks guard, Burn | Hydraulic Slam, Breach Hammer |
| Tralalero Tralala | Shark Dash | Dash, 18 studs | 180%, Slow | Servo Flurry, Stim Dodge |
| Brr Brr Patapim | Spore Burst | Roar, 8 studs | 130%, Poison, a cloud for 3 s | Tremor Slam, Hydraulic Slam |
| Bombardiro Crocodilo | Carpet Bomb | Bombs: 3 rings, 4 studs | 120% each, Stun 0.6 s | Armor Piercer, Kinetic Ram |

## The ten bosses

*2026-10-22: no two bosses fight the same way.* Before this, six of the ten
big attacks were the same 14 stud slam under different names, and the
bombs, leaps and dashes repeated too. Now:

- every boss's **big attack is the only one of its shape**;
- a boss's three moves are **three different shapes**;
- no shape but a strike is on more than two bosses, and where two bosses
  do share a shape, the moves leave different things on you (a shock and a
  slow, a burn and a poison);
- the strikes are each of their own form (how many blows, how heavy, how
  far).

Damage is a share of the boss's hit. The last move in each row is its big
attack.

| Boss | Move | Shape | What it does |
| --- | --- | --- | --- |
| **Tung Tung Tung Sahur** | Tung Tung Tung | Strike, 3 blows | 110% each; the third breaks guard; Burn |
| | Three-Head Roar | Roar, 13 studs | 40%; Blind 35% for 3 s and Slow 30%, through a guard |
| | **Ember Quake** | Slam, 14 studs, 1.6 s | 400%, breaks guard, stun at the core, Burn. The only big slam. |
| **Gattini Gemellini** | Twin Pounce | Leap, up to 26 studs | 200%, Shocked 0.6 s |
| | Claw Frenzy | Strike, 4 blows | 60% each, Sunder |
| | **Static Storm** | Bombs: 5 rings, 1.5 s | 220% each, Shocked 0.8 s. The only big scatter of bombs. |
| **Bombardiro Drago** | Flame Breath | Cone, 16 studs, 70° | 160%, Burn |
| | Tail Sweep | Slam, 9 studs | 160%, Slow |
| | **Firebomb Dive** | Dive, up to 32 studs, 1.5 s | 340% at the crater (11 studs), breaks guard, Burn; three bombs of 4.5 studs scattered round it |
| **Paperotti Gemelli** | Ice Peck | Strike, 2 blows | 120% each, Slow |
| | Hail Volley | Bombs: 4 rings | 140% each, Slow |
| | **Quack Squall** | Wave, 5 to 16 studs, 1.5 s | 300%, Slow 50%; safe at its feet and past 16 studs |
| **Ranocchio Avocadino** | Tongue Lash | Strike, 15 stud reach | 150%, Slow |
| | Toxic Pit | Blast, 5.5 studs | 140%, Poison, a cloud for 3 s |
| | **Swamp Swallow** | Pull, 14 studs, 1.5 s | Everyone in the ring dragged to its feet; 320%, Poison; its feet stay a cloud for 4 s |
| **Chimpanzini Bananini** | Peel Toss | Blast, 4.5 studs | 130%, Slow 50% |
| | Jungle Rush | Dash, 24 studs | 200%, Shocked 0.5 s |
| | **Banana Bounce** | Hops: 3 leaps, 1.5 s then 0.7 s each | 160% each, Shocked at the core; each lands on where you stand then |
| **Tralalero Tralala** | Jaw Snap | Strike, 2 blows | 130% each; the second breaks guard; Sunder |
| | Breach | Leap, up to 18 studs | 180%, Slow |
| | **Tidal Run** | Trail, 30 studs, 1.5 s | 320%, breaks guard, Slow; a frozen wake (5 stud pools every 6 studs) for 4 s |
| **Brr Brr Patapim** | Branch Sweep | Strike, 9 stud reach | 180%, breaks guard |
| | Spore Cough | Roar, 9 studs | 90%, Poison, a cloud for 3 s, through a guard |
| | **Root Surge** | Line, 28 studs, 1.6 s | 320%, breaks guard, Poison; poisoned ground along it (5 stud pools every 7 studs) for 4 s |
| **Frigo Camelo** | Frost Breath | Cone, 14 studs, 60° | 150%, Slow 50% |
| | Door Slam | Strike | 240%, breaks guard, Frozen 0.6 s |
| | **Cold Front** | Aura, 12 studs, 1.5 s | 140% burst, then 45% a second on everyone within 12 studs of it for 6 s, Slow |
| **Cappuccino Assassino** | Knife Flurry | Strike, 5 blows | 50% each, Sunder |
| | Shadow Step | Dash, 24 studs | 180%, Blind |
| | **Kunai Fan** | Fan: 5 paths over 90°, 26 studs, 1.4 s | 240%, Shocked 0.5 s |

The bosses lost the rig maneuvers they had before: Stim Dodge's heal,
Riposte Stance and Pneumatic Jab's interrupt. They still dodge, guard and
parry as before.

## Files

- `src/shared/CreatureMoves.luau` (new): every move.
- `src/shared/DungeonRules.luau`: each fighter's three moves.
- `src/shared/DuelistBrain.luau`: `pickMove` reaches for them.
- `src/server/Systems/Duelist.luau`: they start (rings, rings along a
  path or down a cone, crouch, leap, dash) and land (`creatureMove`,
  `launch`, `landCreature`); an Aura keeps going in `think`. Area moves
  hit a raid's members, not only the one it's on.
- `src/server/Systems/CombatServer.luau`: `afflict` also lands Burn,
  Poison (with a healing cut), Stun and Sunder. A poison ticks as Poison
  and shows as Poisoned.
- `src/client/Combat.client.luau`: a slam's core stun reads FROZEN! or
  SHOCKED! when it's that kind.
- `src/shared/LangEs.luau`: Spanish names for the moves and messages.

## Tests

| Suite | What it covers |
| --- | --- |
| `tests/run_brainrot_bosses.py` | Every move is whole: a shape, a wind-up, damage, a cooldown and a reach, rings wide enough to see, paths with a width, cones you can read, waves with a safe core, effects that land. A big attack is slow to wind up, shows something and has a long cooldown. Each room fighter has its own critter's move and two maneuvers. Each boss has three of its own, no other boss's, and one big attack. No two big attacks share a shape, a boss's three moves are three shapes, no shape but a strike is on more than two bosses, two moves of one shape never leave the same things on you, and no two strikes are of one form. |
| `tests/run_combat.py` (`duelist_cases`) | The brain: the big attack first, a move only in its reach, not mid-dodge, seldom from a guard, not before it's free to attack, a leap not at a foe right beside it, a room fighter's maneuvers still used. The effects: a creature's poison shows as Poisoned, cuts healing and ticks as a share of its hit. Its stun, shred, blind and slow all land. No burn without a creature behind it. |
| `tests/run_rift.py` | The ten bosses still have three moves each, as the Rift's boss. |

## Not tested here

The duelist's movement (a Dash's charge, a Leap's arc) and the rings on
screen run in Roblox only. They need a playtest:

- Does a boss's Leap land on its ring, and do Banana Bounce's three hops
  keep up with a running player?
- Does a Dash charge straight, and does Tidal Run follow the rings it
  showed?
- Does Swamp Swallow's pull read as a pull (you're thrown toward it)?
- Is Cold Front's storm clear on screen as Frigo walks?
- Is a 14 stud ring at 1.5 seconds fair to get out of?
- How often does each boss use its moves?
