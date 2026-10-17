# The Outpost's backdrop: the crater rim and the rift

## The crater rim always loads

The quarry is ringed by a natural crater rim (`craterRim` in
`src/server/World/OutpostWorld.luau`). It's a continuous slope of wedge
triangles from 470 to 770 studs out, cresting about 105 studs high.

With streaming on, Roblox only sends a player the parts near them: up to
1,024 studs at best, and less on a phone or when the map is busy. From
most of the quarry, the rim's far side is 900 to 1,200 studs away, so it
never loaded and the horizon was flat. The jagged peaks before it stood
closer in (480 to 540 studs), so they mostly made it.

The rim's model (`NaturalCraterRim`) is now `Persistent`, like the sky's
planets: every player gets it whole when they join, wherever they stand.
That's about 1,500 parts, sent once.

Its triangles were checked offline. All 1,440 wedges have two corners
exactly on the rim's ring points and the third at the right foot point,
so the rim is built correctly; it just wasn't being sent.

`tests/run_moon_quarry_scene.py` fails if the rim or the sky can stream.

## A rift in the sky

Another dimension seeping in: a rift high in the north sky, past the red
moon. It's drawn by each player's own client (`src/client/Modules/SkyRift.luau`);
the server sends nothing.

![The rift, with the red moon passing in front](outpost-sky/rift.png)

What it's made of:
- **The opening.** A window onto the other side: a slowly turning nebula,
  a swirl of light, and stars in pink, green and gold. A rim of light
  churns round it, with a softer halo outside.
- **Ripples.** Rings leave the rim one after another and spread out, about
  one a second. They shimmer cyan, violet, magenta and gold, break into
  arcs that swirl as they go, and sag a little as they spread, as if what
  comes through were heavy. Each fades in leaving the rim and out at the
  edge, so you never see one restart.
- **The vortex.** Three arms of motes turning slowly round it.
- **Seepage.** Sparks leak out of the rim and drift out and down, and
  glowing motes (3D particles) fall slowly from it toward the quarry.
- **Cracks.** Hairline fractures that flicker round the rim now and then.
- **Surges.** Every 9 seconds the rim flares, a bright ring bursts out and
  every crack lights at once.

![Four moments: a surge, then the ripples moving out](outpost-sky/rift-moments.png)

(Offline renders of the rift's picture over a stand-in sky. In game it
hangs 2,600 studs out and about 35 degrees across, half the screen's
height.)

### Where it is

`SkyRift.Offset` puts it 34 degrees up in the north, above the red moon
and beyond every body in the sky. Its opening clears every
planet, and anything its ripples reach (the red moon, the gas giant's
rings) passes in front of it.

### Cost

It's one BillboardGui of about 110 frames, updated 30 times a second
while you're in the Outpost, and one particle emitter at 5 a second.
Anywhere else it's hidden and nothing runs.

### Code and tests

- `src/client/Modules/SkyRift.luau`:
  - `mount`, `show` and `step` put it in the sky and run it;
  - `draw` builds the picture in any square frame (the billboard, or a
    preview);
  - `ripple`, `surge`, `mote` and `crack` are the timing, as plain
    functions.
- `src/client/Modules/OutpostScene.luau` mounts it on the first frame in
  the Outpost, shows it only while you're there, and steps it.
- `tests/sky_rift_cases.luau` (`tests/run_sky_rift.py`) checks that:
  - it's high in the north, behind the stars;
  - its opening clears the gas giant, the home world and the red moon,
    and those positions still match `OutpostWorld`;
  - every ripple grows outward, sags, stays inside the picture, and fades
    in and out without a pop, with at least three out at once;
  - sparks start at the rim, never show inside the opening, and stay in
    the picture;
  - a surge lasts about a second, every 9;
  - each crack is lit between 5% and 30% of the time.
