# The Outpost's mining rocks

The two rocks that grow in the Outpost, the Regolith Chunk and the Crystal
Boulder, are built from parts by `OutpostWorld.rock`. They no longer use
the imported kit rocks recoloured pale.

![Regolith Chunk, Crystal Boulder and the welcome field](mining/rocks.png)

(An offline render: flat shading and a dark sky. In Studio the Outpost's
daylight makes the stone lighter and the crystals glow.)

## What they look like

- **Dark basalt.** Stone that stands out against the pale regolith: a
  tilted main chunk and stones heaped around it, each at its own angle and
  shade, sunk into a darker bed of disturbed ground.
- **A crystal cluster.** It bursts out of the top face. The tall crystal
  is glass with a glowing core and a pointed tip. Smaller ones fan out
  around it.
- **Ore veins.** Glowing cyan strokes with a bend, across the stone's
  sides.
- **Rubble.** A few stones and a loose chip of crystal at its foot.
- **The Crystal Boulder** is bigger. Its cluster is taller and has a
  second glass crystal, and a second, smaller cluster breaks out of the
  side that faces most upward.

Each one is laid out from its own random seed, so no two rocks match.

## What a rock pays

Every rock pays exactly one gem when it pops, so every rock ends in the
gem reel, a Common at worst. Rocks never pay coins or gear (armour). A
Crystal Boulder takes more swings than a Regolith Chunk, but its gem rolls
luckier (`Depth` in `Shared.Outpost.Sizes`).

Mined gems are mostly Commons, so the good ones are what keeps you mining
(`GemRoller.MiningWeights`; caches, drops and the starter spin keep the
usual 40 / 25 / 20 / 10 / 5):

| | Common | Uncommon | Rare | Ultra Rare | Legendary |
| --- | --- | --- | --- | --- | --- |
| A mined gem, before luck | 60% | 25% | 11% | 3.5% | 0.5% |
| In the core (the rocks' own luck) | 58% | 26% | 12% | 4% | 0.6% (1 in 170 rocks) |
| A guarded Rift Vein (the most luck) | 41% | 30% | 19% | 8% | 1.4% (1 in 72 rocks) |

Further out, the frontier's luck tilts every roll rarer (`docs/frontier.md`).

What Commons are for:
- **Coins.** `SELL COMMONS` in the GEMS window sells every spare one in two
  taps, at the shop's rate (a quarter of a gem's worth, `Config.MarketSellRate`).
  The shop always pays below worth; other players pay better on the market.
  "Spare" means loose and not named by a saved loadout
  (`GemInventory.spare`; the server's `SellSpare`).
- **Your kaiju.** Gems heal a hurt kaiju (a Common of its own element
  20% of its health) and revive one that's down (10 power plus 1 a level);
  they don't give EXP. Its HEAL tab has the spare Commons it needs picked
  already, and AUTO HEAL, switched on, spends spare Commons on the team by
  itself ([kaiju.md](kaiju.md#healing)).

A gem needs room in the pouch (300 gems, room for a long session's
Commons). With a full pouch the server refuses the swing before it lands:
"Gem pouch full (300)! Sell or socket gems to keep mining." The pick isn't
worn and the rock isn't chipped, so no rock is ever mined for nothing.

Coins still come from Tasks, daily challenges, fights and selling gems,
just not from the rocks.

## How many, and where

![Where the rocks grow, before and now](mining/field-map.png)

The quarry holds 180 rocks (`Outpost.NodeCount`), up from 110. Most of the
old ones grew out by the quarry walls, so the middle, where people mine
between fights, was nearly empty.

- **The welcome field:** 8 rocks just ahead of the landing pad.
- **The field round the middle:** 80 spots between 36 and 200 studs from
  the middle. They stay off the roads, the buildings and the lane from
  the pad.
- **The far quarry:** the other 92 rocks spread over the rest of the
  basin, out to the walls.

The server fills the welcome field first, then the field round the
middle, then the far quarry. A rock popped in the middle grows back in the
middle. Rocks stay at least 12 studs apart.

![The view from the landing pad, before and now](mining/from-the-pad.png)

## No mining button (after your first 50 stones)

*2026-10-26.* The small **Tap to mine / Click to mine** button over a rock
in reach only shows while you're learning: your first 50 stones
(`Outpost.MineButton.Training`, counted by `profile.Stats.GemsMined`). After
that there's no button, as in other mining games: tap or click anywhere to
swing at the rock in reach, or walk into it (below).

## The rocks glow: where to mine (on foot and in a mech)

*2026-10-29.* The rocks around you glow so you always see where to go
(`Client.MineCue`, `Outpost.MineCue`):

- the 6 nearest within 42 studs on foot (70 in a mech, measured across the
  ground) get a soft cyan outline;
- the one in reach (the rock a swing would hit) glows **amber**, filled and
  pulsing; a healing crystal glows green;
- over that rock, its label says how: **Click to mine**, **Tap to mine** or
  **X to mine** (to heal, for a crystal), and a click or tap on it swings.
  On foot it shows for your first 50 stones (above); **in a mech it always
  shows**, a size up, as the mech's camera sits further back.

The old label only followed the rock's proximity prompt, which a pilot up
in a mech's cockpit was usually too far from, so it never showed in a mech.
The cue follows the same reach a swing uses instead (`Outpost.Reach` on
foot, `Outpost.MechReach` flat from a mech). A pad's X swings from a mech
too. Nothing glows over an open screen, in a fight or a spar.

## Walk into a rock to mine it

Walking into a rock mines it, as a click or a tap on it does: on foot and
in a mech, on a computer, a phone or a pad, in the Outpost, at the Rift's
healing crystals and on an expedition's wall (`Shared.WalkMine`).

- **On foot**: you're heading into its `Body` (your Humanoid's
  `MoveDirection`, so keys, the thumbstick and a pad alike, at least 0.1 of
  a full push) and your middle is within 2.6 studs of its side
  (`WalkMine.Touch`). Heading into it means within about 70 degrees of
  straight at it (`WalkMine.Facing`, 0.35): walking past it, backing away,
  standing still against it or walking about on top of it doesn't count.
- **In a mech**: the rock its hull stopped against while you drive forward
  (`VehicleDrive.shoving`, for 0.3 s after it last did). A mech never
  pushes through a rock it's mining, however long you hold forward; it
  still pushes through anything else after 1.5 s.
- Looked for every 0.1 s, then it's the same swing a click makes
  (`OutpostScene.swing(id, true)`, `MineScene.swing(index, true)`), so the
  pick's cooldown paces it (0.32 s; a mech's own). It only ever swings at
  the rock you walked into, never at a critter (a click still bonks a
  critter on you first). With your combat kit out, or a screen open, it
  doesn't swing.
- With the pick out of charge, walking into rocks says nothing: PROBE-7
  only opens (and OUT OF SWINGS only shows) when you click or tap.

The hint at the bottom reads "Walk into a rock or click to mine", and
INFO-9 says it too.

## Labels

A rock's name and HP bar show only within 24 studs. Once a rock is hit,
its label shows from up to 60 studs, so you can see who's mining it from
across the field. The label stays up until the rock pops.

**The swing bar** (*2026-10-27*): while you mine, a small tag sits to the
right of the rock you're hitting, with ⛏ and your swings left. The count
drops with each swing, with a little pop, over a bar of them (the free
pick's charge, or a bought pick's wear). It turns red when none are left,
and goes 6 seconds after your last swing (`OutpostScene`'s `SwingBar`, a
billboard on the rock). Tap it for the pick card: the charge and when the
next swing is back. The pick card used to pop up at the top as you
mined.

## Contracts kept

- The main chunk is the `Body`: the model's PrimaryPart, the only part
  that collides or can be queried, and the parent of the mining prompt and
  the PointLight. The light brightens as the rock nears popping.
- The light is a small glow on the rock's own bed: its range is 1.4 times
  the rock's size and its brightness 0.5 (the Saga Monolith and Star Geode:
  1.8 times, at 0.7 and 1.4). The field round the middle holds about a
  hundred rocks. With the old lights (3 times the size, brightness 1.2)
  their pools overlapped, and the floor and the miners on it washed out
  cyan-white. The crystals are neon, so they still glow.
- The first child named `Crystal` sets the colour of the chips and flash
  on each hit.
- Budget: a Regolith Chunk is 19 parts and a Crystal Boulder 29. Only
  parts over 2 studs cast shadows, and the flat bed never does. The lobby
  holds at most 180 rocks (about 4,100 parts).

The Saga Monolith and the Star Geode, which don't grow in the lobby, keep
their old builder.

## Code and tests

- `src/shared/WalkMine.luau`: walking into a rock (`against`, `Touch`,
  `Facing`, `Every`, `Shove`, `Push`). `tests/run_walk_mine.py` checks it
  (into a rock, not past, away, still or on top; a turned rock) and that
  the Outpost, mechs, the Rift and expeditions use it;
  `tests/run_vehicle_transition.py` drives a mech into a rock.
- `src/server/World/OutpostWorld.luau`: `crystalRock` (the two everyday
  rocks), with helpers `shard` (one crystal), `vein` and `upFace`. `build`
  lays out the spots: `ArrivalSpots`, `NearSpots` (`NEAR_SPOTS`) and the
  rest (`ROCK_SPOTS` in all).
- `src/server/Systems/OutpostServer.luau`: `loot` (one gem, nothing
  else), the full-pouch check in `hit`, and `spawnNode` (which spot a
  rock grows on).
- `src/client/Modules/OutpostScene.luau`: `LABEL_NEAR` and `LABEL_MINED`,
  used in `refreshLabel`.
- `tests/run_moon_quarry_scene.py` builds 40 of each rock. It checks:
  - the Body is solid and nothing else blocks walking;
  - the light is there;
  - at least four crystals, with the first one the glow colour;
  - the part budget.

  It also lays out the quarry and fills it with the server's own
  `spawnNode`. It checks that the field round the middle has at least 70
  spots, that none is on the lane from the pad, that it fills first, and
  that a rock popped there grows back there.

  With every rock grown, it samples the floor round the middle every 4
  studs. The rocks' lights may reach at most 15% of it and add up to 0.6
  at most. They now reach 9% and peak at 0.38; the old lights reached 35%
  and stacked to 1.13.
- `tests/outpost_cases.luau` checks that a popped rock pays exactly one
  gem and no coins or gear. It also checks that a full pouch refuses the
  swing without wearing the pick or chipping the rock.
