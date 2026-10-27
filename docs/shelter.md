# The Shelter: the Outpost's base (2026-10-19)

The Outpost keeps its crater basin, but in the middle now stands the
**Shelter**, a big base that holds the lobby. Players arrive inside it.
Everything social and every shop is under its roof, and **outside is
where you mine and kite critters**. It is built by the server with the
rest of the world (`OutpostWorld`, the `shelter` builder).

![The Shelter from above, the quarry round it](shelter/aerial.png)

*(Offline renders from the game's own geometry, flat-shaded, with no
Roblox lighting. Sign text (SurfaceGuis) isn't drawn in them.)*

## Size

168 by 120 studs inside, walls 34 high (an orange glow band and a row of
windows near the top), and a raised glass skylight over the hall (about 44
at its peak). Ribs run up the outside, with heavier corners.

## Inside

![With the roof off: the garage north, the arena in the middle, the stations on the side walls](shelter/cutaway.png)

| Where | What |
| --- | --- |
| North | **Mech garage**: eight bays in a row along the north wall (BAY 1-8, each mech's name on its sign and a jack-o'-lantern over it), every mech facing the lane. The lane runs the full width to a **big door at each end** (east and west, 26 high, EXIT over them, hazard posts, the roller door rolled up). A barrier with three gaps keeps the hall clear. |
| Middle | **Kaiju arena** stage: open floor round it, pylons, the hologram over it. The battles themselves are downstairs: a stairwell west of the stage, a steel plate saying **ARENA**, goes down to the [Kaiju Arena](kaiju-arena.md). |
| West wall | **STORE** and **MARKET** shopfronts (open the Store and the player Market), each a counter with a prompt and its word on a lightbox lit in the shop's own colour (the Store blue, the Market green, a striped stall's canopy, bulbs and crates): see [shopfronts.md](shopfronts.md). Next to the Market, along the south wall, **Ilsa's desk and the Gem Gallery**. The Store shows what it sells on stands: helmets, weapon skins and pickaxes behind the counter, suits on turntables either side ([the Store's stands](probe-store-crew-quarry.md#the-stores-stands)). |
| East wall | The **Hall of Fame** (PvP and PvE columns, trophies on a dais, stanchions in front) and the **bounty office** beside it: talk to Marlo, or walk up to the counter, for the bounty board (every Rift boss, a tab per biome). See [hall-of-fame.md](hall-of-fame.md). |
| South wall, east | **Brutus's duel booth** (DUELS): talk to him, or walk up to his counter, for a 1v1 duel (ranked or casual; win streaks restore your swings: see [swing-restores.md](swing-restores.md)). A sparring dummy and a supply corner beside it. |
| Over the door, inside | **QUARRY**, painted. |

*Since then (2026-10-22): plain one-word signs, and the Shelter's floor cleared (no PROBE-7 station, duel gate, stands or survey table; PROBE-7 and Brutus are crew; the Gem Gallery is next to the Market). See [plain-signs.md](plain-signs.md).*

*And later that day: PROBE-7 removed (Garrick sells the refills), the leaderboard rebuilt as the Hall of Fame, and Brutus given a bounty booth. The day after, Brutus got a duel booth of his own, the bounties an office with Marlo, and the hall its dressing. See [hall-of-fame.md](hall-of-fame.md).*

![From the spawn: the arena ahead, the garage beyond](shelter/hall.png)

![The garage: eight bays facing the lane, the east door](shelter/garage.png)

![The Market and Store booths on the west wall](shelter/west.png)

Since then the hall has gained the Moon Garden (west), the Gem Gallery
(east), a kaiju hologram on the arena's stage, a tiled floor and more
light: see [lobby-polish.md](lobby-polish.md). The old town's shopkeepers
now work here too (Ilsa buys gems at the Gem Gallery; Brutus, Tamsin,
Borin and Garrick by their stations): see
[probe-store-crew-quarry.md](probe-store-crew-quarry.md#the-crew).

In the [serious round](fob-serious.md) (2026-10-20) the booths became shopfronts, the Moon Garden the survey table, every sign one system, and the Halloween dressing moved outside.

- **Arriving**: players spawn just inside the main door, facing into the
  hall (`site.Spawn`).
- **Out the door**: one wide door south (28 wide), an apron, and the
  **welcome rocks** right outside in two clusters flanking a clear lane.
  The haul roads now start at the walls (104 studs out).
- **Mechs** drive out of either garage door. They park back in their bays
  (`site.Parking`); the old Motor Pool is gone.
- **Lights**: three over the garage, four along the hall, two hung over the
  arena from the skylight, plus the signs' own glow.
- **Collisions**: floor, walls, roof, the counters, the barrier and the
  arena are solid. Rocks don't grow in or right against it (its box), and
  wild kaiju keep out (circles over its floor in `KeepOut`).

## Halloween

![The front: giant pumpkins (one in a witch's hat), lights, bats on the roof](shelter/entrance.png)

The old welcome-field decorations were reused: giant carved pumpkins by
the door (one wearing the witch's hat), little and pearl ones, string
lights along the front, bats on the roof edge, and a ghost. Inside there are
ghosts over the arena, bunting across the hall, jack-o'-lanterns over every
bay, pumpkins by the booths and the door, and a web in the garage corner.
Three pumpkin patches stay out in the quarry. The Christmas tree corner is
gone.

## Moved to make room

The landing pad and shuttle are now south-east (72, 118). The solar array
moved west (-150, 40), the fuel tanks east (150, -20, clear of the garage's
east door), and the containers and crates that stood where the Shelter is
were taken out. The scene stays under its part budget (3,833 of 4,000;
3,944 since the lobby was filled in, see [lobby-polish.md](lobby-polish.md)).

## Files

- `src/server/World/OutpostWorld.luau`: `shelter` (the building and its
  places), the Halloween pieces (`pumpkin`, `lantern`, `witchHat`, `ghost`,
  `bat`, `web`, `stringLights`, `bunting`, `harvestPatches`), and `build`
  (the spawn, stations, keep-outs and welcome rocks).
- `OutpostServer`: prompts on the Store and Market counters (`PromptKind`
  `Store`, `Market`). `OutpostScene` opens the Store and the Market from them.
- Tests: `run_moon_quarry_scene.py` (spawn inside, services and stations
  under the roof, bays in the garage facing the lane, no rock in the
  Shelter, roads from its walls, the part budget) and `outpost_cases`
  (station prompts, spawn and bays).

## The crew's tips (2026-10-26)

Every one of the Shelter's crew (Ilsa, Brutus, Marlo, Tamsin, Borin and
Garrick) now has **Give me a tip**: tips about their own station, one at a
time from a random start (`Vendors.<id>.Tips`, the dialogue's `RoleTip`).
Their questions sit under one topic (Ilsa's **Gems and prices**, Brutus's
**Duels and rewards**, Garrick's **The quarry**) so the menu stays short.

- **Ilsa:** which gems to keep (Commons for AUTO HEAL, your kaiju's
  elements), how gems are priced, when to check the Market first.
- **Brutus:** win rewards (two pieces, keep one; rarer the more 1v1 you
  play), win streaks and Arena Caches, best of three, Casual for trying
  loadouts, parrying, the AUTO COUNTER between ranked rounds.
- **Marlo:** threat I to III, what boss caches roll, favourite gear,
  biome elements, the 20 seconds home, the HYPERBEAM on a boss.
- **Tamsin:** six listings for 48 hours, the 5% cut, escrow, empty
  sockets, vault leftovers and your quarter.
- **Borin:** skins never change stats, standard visors and visor skins,
  the stands' 40-second turn, pick skins, the Season Path.
- **Garrick:** never alone past the Core, Rift Veins, Rift Charged, what
  can be stolen, healing only at the Shelter, refills first.

INFO-9's old tip that health refills anywhere in the Outpost now says it
refills back at the Shelter. Every line is in Spanish.
