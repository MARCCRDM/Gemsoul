# How gear looks (2026-10-15)

What you wear is built once, on the server, by `Equipment.luau`, and that one
build is what everyone sees: in the world, in first person, in the Inventory
(its miner and its item thumbnails) and in the Store. Everything that makes the
look is a real part, because a ViewportFrame (every preview) draws parts but not
SelectionBoxes, Highlights, particles or lights.

## Gems show as stones

A gem in a piece of gear is set into it as the stone itself (`gemSocket`):

- a metal bezel with four prongs;
- a glowing core in the gem's own shade (`GemConfig.shade`);
- a faceted glass crown over it.

Where it's set (`STONE_SPOTS`, placed on the outside of the armour by `pieceStones`):

| Piece | Where | Stones |
| --- | --- | --- |
| Helmet | the brow | 1 |
| Chest | the centre of the chest | 1 |
| Gloves | the front of each forearm | 2 |
| Boots | the front of each shin | 2 |
| Shield | its face | 1 |
| Weapon | the hilt | 1 |

A suit, a weapon skin, rarity shine and Prismatic all leave a set stone as it is
(`GEM_PARTS`).

## Its element, from the stone

`gemLook` gives each gemmed piece its element:

- **Trim:** the piece's glowing trims turn the element's colour, unless a suit is worn (then the suit colours them).
- **Light:** a soft light sits in the stone and moves the element's way:
  - Thermal flickers;
  - Cryo pulses slowly;
  - Ion strobes;
  - Corrosive throbs.

  Every client moves it (`GemLights`), from the light's `PulseBase`, `PulsePeriod` and `PulseDim` attributes and its `GemGlow` tag. It used to be a tween on the server, which sent every stone's light to every player every frame, and a copy of it never moved.
- **Effect:** a small effect comes off the stone, busier the rarer the gem:

| Element | Off the stone |
| --- | --- |
| Thermal | a flicker of flame and a few embers |
| Cryo | frost crystals round the setting, snow drifting off it, a breath of cold mist |
| Ion | sparks crackling over it, the odd bright flash |
| Corrosive | bubbles rising off it, a thin wisp of gas |

- **Weapon:** an enchanted weapon's blade carries a little of its element along its length.
- **Gem colour:** the piece carries a `GemColor` attribute, the element's colour. It colours the blade's swing trail (`BladeTrails`) and the first-person shield's glow.

What changed:

- **Before:** the element showed as a coloured outline round the whole piece (a Highlight) and clouds of flame, smoke or gas off its biggest plate. That was busy in the world, invisible in every preview, and Roblox only draws 31 Highlights at once.
- **Now:** the stone is visible on every gemmed piece, the effect is small and comes from the stone, and the look holds in previews.

## Suit trim

A suit's `Seams` and a skin's `Edge` are neon strips set into the plates. See
"The neon look" in `docs/skins-and-selling.md`.

## First person

First person copies your worn weapon and right gauntlet, so its skin, trim and
stone are the same as everyone sees (now that trim and stones are real parts,
they come along too). The copy moves as the worn one does (see below). `ViewGrip.frame` holds the weapon by its blade; a weapon
with no straight piece off its grip is held along the line from the grip to its
farthest piece, rather than not at all.

## Copies move as the gear does

Your first-person weapon, the Inventory's miner (v1 and v2), its item art, the
character screen's portrait, the Shop and Wardrobe previews (`CosmeticView`) and
the lottery's reward art are all clones of the real parts. Three things animate
gear on each client:

- skin trim with a `SeamFx` (`SeamVisibility`);
- Prismatic plates (`PrismaticShimmer`);
- stone lights (`GemLights`).

Each of them finds its parts by CollectionService tag, and a clone can't be
counted on to keep its tags (its attributes it always keeps). That's why a
Nebula sword shifted colour for everyone but you, and stood still in the
Inventory.

So whoever makes a copy calls `LiveLooks.watch(copy)`, and its animated parts
are handed to the animators by attribute (`SeamFx`, `PrismaticBase`,
`PulseBase`). Where a part is drawn decides when it moves
(`LiveLooks.place`):

| Place | Moves |
| --- | --- |
| World (worn gear) | near the camera (trim 120 studs, Prismatic 150, lights 120) |
| Camera (first person) | always |
| View (a preview) | while it's on screen: its ScreenGui on and every frame round it visible, however far off the camera is |
| Away (the Shop's mannequins in ReplicatedStorage) | never: not even checked |

- A copy is forgotten as it leaves the game.
- The character screen's grey silhouette drops its `SeamFx` and `PrismaticBase`, so it stays grey.
- A skin or suit painting over a Prismatic plate takes its `PrismaticBase` as well as its tag, so a copy doesn't shimmer where the worn gear doesn't.
- Previews still can't show particles or lights: a ViewportFrame doesn't draw them.

## Tests

`tests/gear_look_cases.luau` (`run_gear_look.py`) builds real kits with the real
`Equipment` on the real fighter rig, and checks:

- **Stones:**
  - every gemmed piece shows its stones, in the gem's shade, glowing in its element, with its effect;
  - each stone is on the outside of the armour, not buried or covered;
  - Cryo stones grow ice and the others don't;
  - an enchanted blade carries its element.
- **Previews:** no suit, skin or gemmed kit has a SelectionBox or a Highlight.
- **Suit trim:** every trimmed suit has real trim, welded to the body, on its plates' faces.
- **Suits leave the rest alone:** under every suit, stones keep their colour, and an element doesn't recolour a suit's trims.
- **Repeatable:** the same kit builds the same twice.
- **The Armory:** its one-piece previews show their stones.
- **First person:** it can hold all 27 weapon skins, and a weapon with no straight piece.
- **Stone lights:** each carries its pulse (`PulseBase`, `PulsePeriod`, `PulseDim`) and the `GemGlow` tag.
- **Prismatic under a skin or suit:** no plate keeps `PrismaticBase` without its tag.

`tests/live_looks_cases.luau` (`run_live_looks.py`) and
`tests/seam_visibility_cases.luau` (`run_seam_visibility.py`) check the copies,
for animated trim, Prismatic plates and stone lights:

- an untagged first-person copy moves;
- a preview moves while it's on screen, however far off the camera is, and stops when its screen closes or a frame round it hides;
- a far-off worn piece holds still;
- a part drawn nowhere is never touched;
- a copy that leaves the game is forgotten;
- the first-person light breathes at its own (halved) brightness;
- a preview's light is left alone.
