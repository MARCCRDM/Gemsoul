# tools/trailer: the trailer, rendered from the game's code

Makes `docs/trailer/saga-miners-trailer.mp4` (see `docs/trailer.md`). It is
an offline render, not a Roblox capture.

## Needs

- **Lune**, to run the game's Luau offline.
- **Node** with `three@0.160.0` and `playwright`. Run
  `npm i three@0.160.0 playwright` in this folder.
- **Chromium.** Software WebGL is enough: about 5-10 s a frame at 1080p.
- **Python 3** with `numpy`, `Pillow` and `imageio-ffmpeg`.
- **Fonts:** Michroma, Oswald and Montserrat. `stage.html` loads
  `fontface.css`, which should point at local copies.

## Steps

1. **The world:**
   `lune run export_world.luau ../.. world.json`
   (OutpostWorld.build, a rock on every spot).
2. **A Crystal Boulder prop:**
   `lune run export_world.luau ../.. actors/rock_big.json rock Boulder 5`
3. **Every character, posed frame by frame:**
   `lune run export_actors.luau ../.. clips.json actors`
   (CreatureMotion, RivalPose, MechMotion, MineScene's swing, RiftTear).
4. **The roll cards' kaiju:**
   `node portraits.js p_razorback_fire p_carapace_frost p_bulwark_shock`
   (export those three clips first: one frame each, speed 0).
5. **Frames:**
   `node drive.js shots.js out`
   Every shot's frames go to `out/<shot>/NNNN.jpg`. For quick checks,
   `W=960 H=540 SAMPLES=0 PICK=3` renders 3 frames a shot at half size.
6. **Sound:**
   `python3 audio.py audio.wav`
   The theme song cut to the edit, plus the game's sound effects.
7. **Video:**
   `./encode.sh out audio.wav saga-miners-trailer.mp4`

## Inputs not made here

These were rendered with the offline UI preview harness, which is not in
the repo:

- `img/`: the loot card and the starter roll screen.
- `rift/`: the sky rift's frames (`SkyRift.draw`, 10 a second, on black).

`img/logo_keyed.png` is `assets/images/saga_title.png` with its
background keyed out.

## Timing

`shots.js` places every shot on the theme song's bar lines (144.94 BPM, a
bar is 1.656 s). The drop, which is the logo, lands on bar 5.
