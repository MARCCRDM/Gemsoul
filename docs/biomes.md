# The Loop: four biomes round the core

Out past the Outpost's core, the quarry is four biomes, one for each
element and a quarter of the quarry each. Four haul roads (the **Spokes**)
run out of the core due north, east, south and west between them, and the
ring road at 260 studs runs round through all four. Each biome has its own
ground, rocks, landmarks and light. Its gems, wild kaiju and critters lean
toward its element.

Going round **clockwise** from the north-east, each biome is weak to the one
before it. So what you catch and mine in one biome does well in the next:

**Ashfall** (Thermal) → **Rimefrost** (Cryo) → **Stormglass** (Ion) →
**Blightwood** (Corrosive) → back to Ashfall.

(`Shared.ElementMatchup`: Thermal beats Cryo, Cryo beats Ion, Ion beats
Corrosive, Corrosive beats Thermal.)

![The Loop from above: the four biomes, the spokes, the ring road and its clockwise arrows, the rocks by band, the landmarks and the crossroads signs](biomes/loop-map.png)

The pictures are offline renders of the parts the server builds
(`OutpostWorld.build`). The map is a flat top-down drawing of those parts,
and the 3D views come from the trailer renderer. They are **not Roblox
screenshots**:
- Roblox draws each ground's material texture (cracked lava, snow, salt,
  mud); the renders show only its colour.
- The signs' text isn't drawn.
- The screen grade and light that shift as you walk into a biome happen on
  the client and aren't in the renders.

## The four

| Biome | Where | Element | Ground | Rocks | Landmarks |
| --- | --- | --- | --- | --- | --- |
| **Ashfall** | North-east | Thermal | Ash over cracked lava | Rust-red basalt | Smouldering vents, an ember in each throat; every other one smokes |
| **Rimefrost** | South-east | Cryo | Snow | Blue-grey basalt | Clusters of ice spires on a drift of frost |
| **Stormglass** | South-west | Ion | Violet salt flats | Violet basalt | Pylons of storm glass with a charge running up the core |
| **Blightwood** | North-west | Corrosive | Green mud | Moss-dark basalt | Dead trees in the mud, a spore pod swelling on a branch |

![Each biome at ground level: Ashfall, Rimefrost, Stormglass, Blightwood](biomes/ground.jpg)

The core is the **Hub**: the moon's own grey regolith, with all four
elements alike.

### How a biome is built

All of this is in `OutpostWorld`:

- **Its floor**: the whole quarter in its own ground, from the core's edge
  out under the quarry walls. It's 8 slices of flat triangles (`biomeFloor`).
  The edge toward the core is ragged but meets its neighbours at the spokes,
  and the seams between biomes run under the spoke roads.
- **On it**: 10 broad patches in a darker tone of its ground, and the
  quarry's regolith patches tinted to match.
- **6 landmarks** (`biomeGround`), at least 44 studs apart and clear of the
  rocks, roads and buildings.
- **Its rocks' basalt** is the biome's (`rock(size, cframe, rng, tint,
  stone)`). The crystals keep their band's colour, so you can still read a
  rock's luck.
- **Ground layers**, from the bottom up: the quarry floor (0), a biome's
  floor (0.04), its patches (0.07), the regolith patches (0.1), the roads
  (0.16). Nothing sits close enough to flicker.

## What leans

| | In a biome | In the core |
| --- | --- | --- |
| **Mined gems** | Its element 60% of the time; the other three share the rest (about 13% each). Rarity, luck and everything else are as before | All four alike |
| **Wild kaiju** | Born its element 60% of the time | All four alike |
| **Critters** | An encounter's critters are its own kind 60% of the time: Tung Tung Tung Sahur in Ashfall, Tralalero Tralala in Rimefrost, Brr Brr Patapim in Blightwood | (No rifts in the core) |
| **Stormglass's critters** | Its own kind is the ranged Bombardiro Crocodilo. It never comes alone and always comes last, so in Stormglass a wave of two or more has more of them at the back (a 6-wave has 2), and the rest are any of the others | |

Notes:
- A rock's lean comes from where it grows; a vein's rocks lean too.
- A rift's critters lean toward the biome of whoever it opened at; a
  wandering rift's lean toward the ground it opens over.
- Gems from elsewhere (the Rift, dungeons, the store) don't lean.

The numbers are `Frontier.Biome`:
- `Bias` 0.6, for gems and wild kaiju;
- `Critter` 0.6, for critters;
- `Blend` 60 studs, how far the light takes to come in.

## Finding your way

![The north crossroads (Blightwood's sign left, Ashfall's right) and the Loop from above](biomes/crossroads.jpg)

- **Crossroads signs**: at each spoke's mouth, 30 studs out of the core,
  there's a sign either side of the road. Each names the biome on that side
  in its colour, with its ground under the name (**ASHFALL**, Thermal
  ground). That's 8 in all, facing whoever's heading out.
- **The way out**: 8 lone rocks stand at the spokes' mouths, two to each
  road, a step either side of it. They lead out of the core into the first
  rocks of each biome.
- **The banner**: cross into a biome and its name shows at the top of the
  screen in its colour, with its line: "Thermal ground · Thermal gems,
  critters and kaiju". It waits for a band's banner to finish first, and
  the same biome's banner won't show again for 20 seconds.
- **The light**: the screen's grade and the outdoor light shift toward the
  biome's as you walk out. The shift starts 30 studs inside the core's edge
  and is complete 30 studs past it. On a spoke it's an even mix of the two
  either side. It eases in a little at a time, and it's left alone while
  you're in the Rift.

The server sets each player's biome as the `FrontierBiome` attribute (the
biome's Id, or nothing in the core), next to `FrontierBand`.

## Spanish

The names and lines are in `Shared.LangEs`:

| English | Spanish |
| --- | --- |
| Ashfall | Cenizal |
| Rimefrost | Escarcha |
| Stormglass | Vidriotormenta |
| Blightwood | Bosque Marchito |

So is each ground ("Terreno térmico") and each banner line ("Gemas, bichos
y kaiju térmicos"). The crossroads signs are drawn on the world, like the
Outpost's other signs. The translator covers the screen and the prompts, so
the signs stay in English.

## Where it lives

| File | What |
| --- | --- |
| `src/shared/Frontier.luau` | The rules: `Spokes`, `Biomes` (each one's Id, name, ground label, element, angle, ground colour and material, stone, glow, screen tint, outdoor light, banner line), `Biome` (`Bias`, `Critter`, `Blend`), `biomeOf(angle)`, `biomeAt(offset)` (nothing in the core), `biomeMix(offset)` (the light's weights), `pickElement(home, rng)`; the stepping stones at the spokes' mouths (`Outcrop.Stones`) |
| `src/shared/GemRoller.luau` | `roll(rng, luck, rarity, base, home, bias)`: a gem's element leans toward `home` |
| `src/shared/Kaiju.luau` | `wave(count, rng, home, bias)`: an encounter's critters lean toward the biome's own kind |
| `src/server/World/OutpostWorld.luau` | Each biome's floor, patches and landmarks (`biomeFloor`, `biomeGround`); the crossroads signs (`crossroads`); the spoke roads and ramps; rocks in the biome's stone |
| `src/server/Systems/OutpostServer.luau` | A rock's gem leans toward its spot's biome; each rock gets its biome's stone |
| `src/server/Systems/GemGenerator.luau`, `Gems.luau` | Pass the lean (`Home`, `Bias`) through to `GemRoller` |
| `src/server/Systems/KaijuWilds.luau` | Wild kaiju born in a biome lean to its element; `pickWave` and `pickCritter` lean toward its critter |
| `src/server/Systems/FrontierServer.luau` | Each player's biome (`FrontierBiome`); a rift's critters lean toward the biome it opens in |
| `src/client/Modules/FrontierHud.luau` | The biome banner (`biomeLines`) and the light blend (`biomeLight`) |
| `src/client/Modules/QuarryLife.luau` | The road lights along each spoke |

## Tests

| Suite | What it checks |
| --- | --- |
| `run_frontier` | Four spokes, due north, east, south and west. The matchup chain round the Loop. `biomeOf`, `biomeAt` (nothing in the core), `biomeMix` (weights add up, even on a spoke, the blend coming in across the core's edge). `pickElement` at 60% over many draws. `GemRoller` leaning toward the biome and not without one. The stepping stones at the spokes' mouths. The banner's lines and the light's targets |
| `run_kaiju` (`kaiju_cases`) | Waves in each biome: its own kind 57–63% of the melee critters with the others alike. In Stormglass, at least one ranged critter in every swarm, always at the back, and more of them than elsewhere |
| `run_moon_quarry_scene` | Each biome's floor covers its quarter (its area within 3% of the quarter's), flat, in its own ground and material, with no shadows. Its patches and landmarks in its own quarter past the core, with a glow among the landmarks (all but Rimefrost's). A sign either side of every spoke (8). Four spokes and their ramps |
| `run_quarry_life` | The road lights along every spoke |
| `run_lang` | Every name and line has its Spanish |
