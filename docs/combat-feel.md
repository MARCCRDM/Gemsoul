# Combat feel: your blade landing, and kaiju that move like animals

Two things felt flat. Landing a sword blow didn't feel like anything, and
the kaiju slid about with stiff poses and little sign of a cast coming.
This round fixes both. Everything here is presentation only. Damage, timing
and rules haven't changed.

The renders below come from `tools/vfx_sim.luau` and `tools/vfx_render.py`
(the real client modules, run offline on a virtual clock). They are
stand-ins for the game: grey blocks in place of the real bodies, with no
Roblox lighting and no bloom.

## Your sword

Why it felt flat:

- **Your swing waited on the server.** The first-person swing only started
  when the server answered, a full round trip after you let go. Every blow
  felt late.
- **Nothing happened on contact.** The blade swept on through the target
  as if it had missed: no stop, no jolt, no flash on what you hit. The
  sound and the number were the same as anyone else's hit.

What it does now:

| | |
|---|---|
| **Swings at once** | The swing, its whoosh and its crescent play the moment you let go (`Combat.client`: `own.swing`). The server's reply no longer restarts it. |
| **Hit stop** | When the blade connects, the swing stops dead for a beat as it bites, then carries on (`FirstPersonCombat`: `View.contact`). A cut holds about 65 ms, a heavy 100 ms. Crits, kills and each combo step hold a little longer, up to 170 ms. If the server's word comes before the blade reaches the cut, the stop waits for the blade. |
| **The bite** | While it holds, the blade shudders and presses into the cut. |
| **View kick** | Your view jars one way and springs back (`CombatFx.kick`): across with a cut, down with a heavy chop. Crits and kills jar harder. |
| **Hit flash** | What you hit flashes white-hot, then fades through your gem's colour (`HitFlash`, a small pool of Highlights within `OutlineBudget`'s room). |
| **Contact spark** | A white-hot streak laid along the cut, a hard four-point flare, and sparks thrown on the way the blade was going (`CombatVfx.contact`). |
| **Contact thud** | A meaty layered thud (`Contact`, or `HeavyContact` for a heavy or a kill) that climbs in pitch through a combo. |
| **Damage numbers** | Your own numbers wait for the bite and come up bigger, with a stronger pop. |
| **Controller rumble** | A short rumble on a gamepad. |
| **Guarded blows** | A blow on a guard stops short and rings off it (`Deflect`). The blade bounces back, a blue-white glint and sparks fly back at you, and nothing flashes. |

![Contact: a cut, a heavy, a crit and a guarded blow, 0.02 to 0.25 s](combat-feel/contact.jpg)

How it fits together:

- The server sends **`Contact`** to the swinger alone (`CombatServer`'s
  `attack`), once per melee swing that met someone. It carries what it hit
  (model and position) and `{ Heavy, Crit, Blocked, Kill, Combo, Element }`.
- `SwordFeel.tune` turns that into numbers: the stop, the shudder, the kick,
  the spark's size, the flash, the sound and the rumble.
- The tests in `tests/run_sword_feel.py` pin those numbers down, and
  `tests/combat_cases.luau` checks that Contact goes only to the swinger,
  with what the blade hit and whether it was guarded.

## Kaiju

| | |
|---|---|
| **Blows with weight** | A blow carries a touch past its pose (a back-out ease), holds a beat as it lands (`Motion.Hold`, 60 ms), then settles. The wind-up and the blow crossfade so they never stack. |
| **Anticipation** | A heavy shivers at the top of its wind-up, just before it comes down. |
| **Casting** | The body trembles and swells as a cast gathers. |
| **Charge-up** | An orb of the kaiju's element swells at its mouth over the wind-up, with motes drawn in and its light growing. It bursts as the cast is let go, with a flash and a ring (`KaijuMotionFx.charge` / `release`). A cast cut off by a hit just fizzles out. |
| **Walking** | `CreatureMotion.gait`: the weight dips onto each foot as it lands and rolls from side to side, and the body leans into a run and twists against the stride. It banks into turns. Standing still, it breathes and shifts its weight. |
| **Footsteps** | Dust kicks up and a ring spreads along the ground at each footfall. Big kaiju also thud, and giants shake your screen when they're close. Hovering kinds don't leave footprints. |
| **Getting hit** | A blow snaps the body back hard and eases out, and the body flashes. This covers any creature: kaiju, critters and bosses. |

![A kaiju's cast gathering and let go, per element](combat-feel/kaijucharge.jpg)

![Footfalls](combat-feel/kaijusteps.jpg)

The kaiju changes are tested in `tests/kaiju_models_cases.luau`. They check
that a blow carries through, holds and settles, that a cast trembles, and
that the walk dips, rolls, leans and banks within limits.

## Sounds

`tools/make_combat_sounds.py` builds every combat sound from scratch
(`pip install numpy scipy soundfile`, then run it). It writes MP3s into
`assets/sounds/combat`, and `_preview_all.mp3` plays them all in a row.

**The game can't play these files yet.** Roblox only plays audio uploaded
to Roblox, and none of the combat sounds has been uploaded: every id in
`CombatSound.Ids` is still `0`. Until they are, `CombatSound` plays
stand-ins layered from Roblox's built-in sounds (`FALLBACK`). To switch the
real ones on, run

    python tools/upload_audio.py --key YOUR_API_KEY --user YOUR_USER_ID

It uploads each file and writes its id into the `Name = 0, -- file.mp3`
line in `CombatSound.luau`. See the top of that script for how to get a key.
Roblox limits how many audio files an account can upload in a month.
Uploaded ids are kept in `tools/audio_ids.json`, so a run that hits the
limit can simply be run again later.

New sounds:

| Sound | Takes | What it is |
|---|---|---|
| `Contact` | 4 | Your blade landing, played in your ears with the hit stop. An edge slicing in, a hard bite, a deep punch you feel, a wet body thud and a tick of steel. It's short and dry so a fast combo stays crisp, and it climbs in pitch through the combo (`SwordFeel`). |
| `HeavyContact` | 2 | The same, for a heavy or a kill: a deeper boom, more body, and debris pattering down. |
| `Deflect` | 2 | Your blow turned on a guard: steel rings off it, skids, and a little tink. |
| `Stomp` | 2 | A big kaiju's footfall: a deep thud, dirt crunching, grit falling back. |
| `Charge` | 1 | A kaiju's cast gathering. A whine climbs and trembles faster as the orb swells, timed to peak just as the cast is let go. It has no built-in stand-in, so it's silent until it's uploaded. |

Improved sounds:

- **Swings** (4 takes, heavies 3) have a fast "vwhip" at the peak of the
  arc, over the rush of air.
- **Hits, heavy hits and crits** gain the slicing edge and a body thud
  under the old click, crunch and clank, with a sharper attack.
- **Hurt** has a body thud, and the **kill** has a ringing "shing" and a
  deep drop under it.
- **The room:** every sword sound now sits in a short stone-arena
  reverb, where the highs die first, in place of the old flat echoes.
- **No clicks:** every layer now fades out before its buffer ends. Before,
  some layers were cut off mid-ring, and that left a click.
- **No clipping:** each file is read back after MP3 encoding. If a sharp
  attack went over the limit, the file is re-encoded quieter.

`tests/run_combat_sound_ids.py` checks three things. Every file has its id
slot (so the uploader fills it in), every slot has its file, and a sound's
takes are numbered 1, 2, 3 with no gaps (`CombatSound` stops looking at the
first missing number).
