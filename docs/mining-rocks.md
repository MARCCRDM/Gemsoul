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
  holds at most 110 rocks.

The Saga Monolith and the Star Geode, which don't grow in the lobby, keep
their old builder.

## Code and tests

- `src/server/World/OutpostWorld.luau`: `crystalRock` (the two everyday
  rocks), with helpers `shard` (one crystal), `vein` and `upFace`.
- `src/client/Modules/OutpostScene.luau`: `LABEL_NEAR` and `LABEL_MINED`,
  used in `refreshLabel`.
- `tests/run_moon_quarry_scene.py` builds 40 of each rock. It checks:
  - the Body is solid and nothing else blocks walking;
  - the light is there;
  - at least four crystals, with the first one the glow colour;
  - the part budget.
