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

A gem needs room in the pouch (200 gems). With a full pouch the server
refuses the swing before it lands: "Gem pouch full (200)! Sell or socket
gems to keep mining." The pick isn't worn and the rock isn't chipped, so
no rock is ever mined for nothing.

Coins still come from Tasks, daily challenges and fights, just not from
the rocks.

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

## Labels

A rock's name and HP bar show only within 24 studs. Once a rock is hit,
its label shows from up to 60 studs, so you can see who's mining it from
across the field. The label stays up until the rock pops.

## Contracts kept

- The main chunk is the `Body`: the model's PrimaryPart, the only part
  that collides or can be queried, and the parent of the mining prompt and
  the PointLight. The light brightens as the rock nears popping.
- The first child named `Crystal` sets the colour of the chips and flash
  on each hit.
- Budget: a Regolith Chunk is 19 parts and a Crystal Boulder 29. Only
  parts over 2 studs cast shadows, and the flat bed never does. The lobby
  holds at most 180 rocks (about 4,100 parts).

The Saga Monolith and the Star Geode, which don't grow in the lobby, keep
their old builder.

## Code and tests

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
- `tests/outpost_cases.luau` checks that a popped rock pays exactly one
  gem and no coins or gear. It also checks that a full pouch refuses the
  swing without wearing the pick or chipping the rock.
