# Helmet skins

Thirteen helmet skins. Each one is a whole new head in place of the helmet
you wear. The helmet keeps its stats, rolls and gem; only its look changes.
Each skin has its own silhouette, built from parts welded to the head and
sized to it, so it fits any avatar. Three of them are for Halloween.

![The thirteen helmet skins, front and back](helmet-skins/lineup.png)

| Skin | The look |
| --- | --- |
| Hard Hat | A ribbed yellow site helmet with reflective tape, a gem sticker and a headlamp corded to a battery pack (red tail light). Amber goggles, ear defenders, a dust mask. |
| Star Bubble | A 1950s fishbowl space helmet: a white comms cap with a racing stripe, a smoked shield with eyes behind it, a blinking antenna, and a life-support pack with air tanks on the collar. |
| Arena Plume | A bronze gladiator's helmet with a wide brim, a grille face with two eye grilles, a red horsehair crest, white feathers and a flared neck guard. |
| Deep Diver | A copper diving bonnet: a riveted brass faceplate with glowing eyes behind the port, grilled side ports, wing nuts, a nameplate, an air valve and hose, and bubbles. |
| Jarl's Horns | An iron spangenhelm with spectacle guard and nasal, mail flaring over the shoulders, a braided ginger beard, a fur collar and great ivory horns. |
| Shark Bite | Your head in a shark's jaws, eyes glowing in the dark of its mouth, with a dorsal fin and a tail fin. |
| Shogun Kabuto | A black-lacquered kabuto: a gold crescent crest, a three-tier neck guard, a red war mask with gold teeth, and a burning red stare. |
| Sun Pharaoh | A gold death mask in a lapis-and-gold headcloth, the cobra on its brow, and a burning sun disc between golden horns. |
| Mech Ace | A mobile-suit head with a gold V-fin, slanted green eyes, panel lines, a lit rear vent and an antenna. |
| Wyrmking | A crimson dragon's head: a long snout with fangs and fire in its jaw, ember eyes, gold-tipped horns, frills, a scaled back and smoke from the nostrils. |
| Jack-o'-Helm *(Halloween)* | A pumpkin with a carved, flickering grin, lit from inside, its lid cut glowing round the stem, embers rising off the top. |
| Grim Reaper *(Halloween)* | A hood with a long, drooping tail round a bone skull with green fire in its eyes, a tattered mantle and green mist. |
| Witch's Brim *(Halloween)* | A drooping witch's hat with a crescent charm and a spider let down from the brim, over a green face with violet eyes and lank hair. |

## Visors on helmet skins

Every helmet skin has eyes that glow, and the eyes always take the selected
visor's colour and movement. A dark glass visor such as Smoke is brightened
until it glows, so the eyes never go dark. Each skin keeps its own eye shapes:
nothing is cut into bands or framed. A visor's particles, sparks and light come
off both eyes alike.

- **Character helmets** (Shogun, Pharaoh, Mech Ace, Wyrmking, Jack-o'-Helm,
  Grim Reaper, Witch's Brim): their own eyes light in the visor's colour.
  Their glows change colour too: the light inside the pumpkin and its lid
  cut, and the lamps by the eyes. With a visor that holds still, a skin's
  own flicker or pulse carries on in the visor's colour.
- **Glass-faced helmets** (Hard Hat, Star Bubble, Arena Plume, Deep Diver,
  Jarl's Horns, Shark Bite): the glass takes the visor's tint, and the eyes
  glow behind it in the visor's colour.

Without a visor, each skin shows its own eye colour.

![Character helmets with visors](helmet-skins/visors-eyes.png)

![Glass-faced helmets with visors](helmet-skins/visors-lens.png)

Standard helmets take visors exactly as before (bands, rims, a dark lens
behind).

## How it's built

`src/server/Systems/HelmetLooks.luau`:

| Function | What it does |
| --- | --- |
| `HelmetLooks.build(component, character, look)` | Builds skin `look` into the helmet's model, round the character's head. |
| `HelmetLooks.restore(component)` | Puts the skin's own colours back after the gem, rarity and suit passes. Run it before the visor is applied. |
| `HelmetLooks.has(look)` | Whether `look` is a known skin. |
| `HelmetLooks.Looks` | The designs. |

Each part can carry these attributes:

- `VisorFace` marks an eye or lens.
- `VisorFit` is `"Eye"` (a glowing eye) or `"Lens"` (glass in front of the eyes).
- `VisorTint` marks a part lit by the same light as the eyes, such as the
  pumpkin's lid cut.
- `VisorLight` is set on a light that the eyes give off.
- `StoneSeat` marks where the helmet's gem sits.

`Equipment.applyVisor` fits the visor to any helmet whose lens parts carry
`VisorFit`. It does this in `fitVisor`. Helmets without `VisorFit` (the
standard ones) are unchanged.

## Status

The designs and the visor fitting are done. The skins are **not yet in the
game**: no Cosmetics entries, store listing, wardrobe tab or preview wiring.
That comes next, along with tests for the fitted visor path, which only runs
once a skin can be worn.

The images are rendered from the game's own building code with a stand-in
renderer. They haven't been checked in Roblox Studio yet. Each skin uses
roughly 12 to 72 parts; Wyrmking, Jarl's Horns and Witch's Brim are the
heaviest.
