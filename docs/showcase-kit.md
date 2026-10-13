# The showcase starter kit (2026-10-13)

A new player picks a style and an element. Each of Q, E and R is then rolled
from two showcase moves of that element (`GemTraits.Intro`). These are the
flashy moves; for now, the intro picks them for looks and fun, not for depth.
R is never a shield. It is a wall, or a move that changes the ground around
you. Shields still exist as R moves on gems mined later.

| Picker: what each key can roll | The roll: each card's circle is a reel that lands on your gem, which gives up its surge |
| --- | --- |
| ![Picker](showcase-kit/picker.png) | ![Reveal](showcase-kit/reveal.png) |

## The pools

| Element | Q (sword) | E (core) | R (defense) |
| --- | --- | --- | --- |
| Thermal | Furnace Crescent / Magma Fault | Supernova / Heat Haze | Fire Wall / **Ring of Fire** |
| Cryo | Glacier Fan / Permafrost Spire | Absolute Zero / Cryo Stream | Frozen Wall / **Ice Pillar** |
| Ion | Circuit Cleave / Railstorm | Chain Lightning / Thunder Pylon | **Tesla Fence** / **Hologram Decoy** |
| Corrosive | Caustic Dart / Vitriol Sweep | Toxic Cloud / Leech Bloom | **Spore Wall** / **Acid Slick** |

Each element has two R moves: one **barrier** and one **escape**
(`GemTraits.Showcase`).

## The six new R moves (in bold above)

| Move | What it does |
| --- | --- |
| Ring of Fire | A ring of flame circles you for 4s. Foes who cross it burn and get thrown back. |
| Ice Pillar | An ice column lifts you out of sword reach for 2.5s, then shatters and slows everyone nearby. |
| Tesla Fence | A curtain of lightning bolts striking down, with arcs jumping between them. It stops bolts, and foes who walk through are stunned. |
| Hologram Decoy | You blink back and leave a flickering copy of yourself. It explodes in lightning when a foe gets close. |
| Spore Wall | A hedge of toadstools. It stops bolts and poisons foes who walk through. |
| Acid Slick | A bubbling acid pool. Foes standing in it are slowed and their armor is shredded. |

![The six defenses](showcase-kit/defenses.png)

They are part of the full catalog: the matrix now has 66 moves, up from 60.
Gems mined later can roll them too.

## What it replaced

- **Before:** every starter kit got fixed moves: Offense #2, Ability #1 and
  Defense #1 of its element's matrix. For three of the four elements, R was a
  shield.
- **Now:** `StarterLottery.prepareChoice` rolls each key from its pool on
  the server and saves the result as `reward.Moves` (kit `Version = 4`).
  Retrying never re-rolls the kit.
- **To go back to fixed moves:** in `src/shared/GemTraits.luau`, give each
  `GemTraits.Intro[element]` lane a one-item list.
