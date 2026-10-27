# Level ups, CALL BACK / DEPLOY, the lobby card and buttons, the gem card's value

A round of fixes and additions alongside the Rift (`docs/rift.md`). The
UI pictures are the client code rendered by the UI harness, not Roblox
screenshots.

## Level ups

`Client/LevelUpFx`, sent by the server through CombatFx so everyone near
sees them:

- **A miner's** (`Progress`): a column of amber light out of the ground,
  two rings running out over it, sparks spiralling up round the body, a
  flash, and the new level on a plate over the head. You also get your
  level-up card at the top of the screen (below).
- **A kaiju's** (`KaijuServer`): the same in its element's colour, at its
  size. Its card says what the level brought ("Its Q move, Tidal Crush,
  awakens." or "More health and damage.").
- Sounds: a climbing chime for a miner, higher and quicker for a kaiju
  (`tools/make_levelup_sounds.py`, `assets/sounds/combat/level_up.mp3`,
  `kaiju_level_up.mp3`; ids in `CombatSound` like the other combat sounds).
- Built from plain parts posed from one clock, gone after 2.6 seconds; it
  follows the body it's on. The plate's words are translated in place.

### Your level-up card

It was too big: a 440 x 108 card with rays and sparks round it on a
computer, and a third of a phone's height on small phones. Now it's a slim
pill (`LevelUpFx.banner`, `cardLayout`, `card`, `poseCard`):

- **A small medal** on the left with the new level in it. The old number
  rolls up out of it as the new one comes in, and the medal pops a little.
  It's amber for you and the element's colour for a kaiju.
- **The words:** **LEVEL UP!** (or a kaiju's name, which shrinks to fit
  and isn't translated), and under it what the level brought, on one line.
  When the level brought nothing to say, it says YOU REACHED LEVEL 12 (or
  YOUR KAIJU REACHED LEVEL 10) instead.
- **The pill:** dark glass with a touch of its colour behind the medal, a
  faint rim in that colour. A thin line under the words runs down while it
  stays. No rays, sparks, halo or shine; about 15 pieces instead of 60.
- **Size:** 340 x 46 on a computer, 64 down from the top; 210 x 36 on a
  phone.
- **Timing:** it drops in a little, stays about 2 seconds, then lifts and
  fades (2.8 s in all, was 3.8). One at a time, as before.
- **On a phone** it sits in the top middle, between the pick card's place
  and the toasts, clear of the loot card. On a phone too narrow for that
  (most, now that the pick card sits beside your kaiju's card), it drops
  under the pick card's place, left of your health, loot card and toasts.
  While it's up, the live feed steps aside (`MobileLayout.claimTop`).

![Before (top) and after: yours and a kaiju's, on a computer](levelup-lobby/level-card.jpg)

![On a phone (844 x 390): yours before and after, then a kaiju's before and after](levelup-lobby/level-card-phone.jpg)

These are the client code drawn by the UI harness, 1.2 s in. They aren't
Roblox screenshots.

## Kaiju levelling, slower

Kaiju were levelling too fast. Both sides of it are slower:

| | Before | Now |
| --- | --- | --- |
| EXP for a level | `80 x level^1.5` | `110 x level^1.65` (`Kaiju.ExpCurve`) |
| EXP per rock mined | Pebble 5, Boulder 8, Monolith 12, Geode 20 | 3, 5, 8, 13 (since then, none: rocks level you, not your kaiju; [levelling.md](levelling.md)) |
| EXP per kill | `40 + 12 x level` | `26 + 8 x level` |

Level 5 to 6 now takes 1,563 EXP (was 894); level 10 to 11, 4,913 (was
2,529).

## CALL BACK / DEPLOY

![The kaiju strip: out, called back, in danger](levelup-lobby/kaiju-strip.png)

The strip's AUTO HEAL button is split: **AUTO HEAL** and, beside it,
**CALL BACK**. Called back, your team folds into points of light that fly
to you, and the button reads **DEPLOY**. Deployed, they open out of a shard
of light from you. Sounds: `call_back.mp3`, `deploy.mp3`. (*2026-10-27:*
DEPLOY works in danger too, at once; it used to wait till you were clear
of the fight. See [kaiju.md](kaiju.md), Teams 1 to 4.)

## The lobby card and side buttons

![The lobby: PLAY, the button grid, the player card and its health bar](levelup-lobby/lobby.png)

- **Your health** is a bar under the player card (HEALTH, current / max).
  On phones it's a slim HP bar.
- **The side buttons** (PLAY, then INVENTORY and a grid of TASKS, MARKET,
  STORE, RANKS, SOCIAL, INVITE) are one panel with drawn icons and
  hairline dividers instead of loose chunky buttons. PLAY's subtitle reads
  SELECT A MODE, or how many are online and searching.

## The gem card

![The gem card: every property and how its value adds up](levelup-lobby/gem-card.png)

The pips no longer overlap the labels, on desktop or phones. The card now
shows everything that sets a gem's value:

- **Rarity** and its **TIER n OF 5**;
- **Size** (Magnitude), **Clarity** (Duration), **Cut** (Precision), each
  with its grade and a bar;
- **HOW ITS VALUE ADDS UP**: each grade's points times its weight (Size
  x10, Clarity x5, Cut x15: `Economy.GemWeights`), the grade points, the
  rarity's rate, and the value. A Prismatic Arc Gold: 265 points x 5.4 =
  1,431;
- what it does **IN A WEAPON**;
- Prismatic gems say so in the subtitle.

On phones (short screens) the header is compact, the search is hidden and
the stone sits beside the details.

![The gem card on a phone](levelup-lobby/gem-card-phone.png)

## The Outpost

- **The searchlights** sweeping the sky outside the FOB are gone.
- **The neon strips** on the ground that marked the trails are gone.
- **Every mech is a Mole drill**: all eight bays in the garage.
- **You spawn facing a mech**: in the garage lane, looking at bay 04's
  Mole drill.
- **The Store's stands** show skins only (a suit alone, no sword or shield
  on the stand) and change every 12 seconds, turning faster.
- **Critters carry the real gem**: a thief holds the very gem it took over
  its head, drawn like the gem art, and drops that stone when you hit it.
- **Kaiju jump with you**: when you jump, your team hops after you one by
  one (0.1 s, then 0.16 s apart). (Since reworked into a follow-the-leader
  line, nearest first and further apart: see `docs/kaiju.md`.)
- **The Rift Veins' beams** are replaced by Rift Gates (`docs/rift.md`).

## Tests

| Suite | What it checks |
| --- | --- |
| `run_levelup_fx` | The column, the rings, the sparks, the flash, the plate, a kaiju's at its size, following its body, gone after 2.6 s, sent and drawn, its sounds. Your card: across the top middle on a computer; on every phone size on the screen, at the top, clear of the pick card, toasts and loot card; its words and a kaiju's name (not translated); the number turning over with sparks, the rays turning, the line running down, gone at the end; its Spanish |
| `run_kaiju` | The EXP curve and mining EXP; CALL BACK, DEPLOY (in danger too, not while you're down); kaiju jumping after you; `restoreAll` |
| `run_gem_metric` | A gem's worth: grades, weights, points, rate, value |
| `run_critter_fx` | The carried gem is the real gem |
| `run_store_displays`, `run_quarry_life`, `run_moon_quarry_scene`, `run_outpost` | The stands, no searchlights, Mole drills in every bay, the spawn facing one |
| `run_mobile_layout` | The lobby card and buttons on phones |
