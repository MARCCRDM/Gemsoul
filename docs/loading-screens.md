# Loading screens

Nothing is shown half loaded. The loading screen covers the view whenever it's
about to change and stays up until what's behind it is ready. That's at least
a moment (so it never just blinks) and never longer than a safety limit.

![Loading screen](loading-screens/desktop.png)

A phone held sideways gets the same screen, slightly bigger, with the tip
pinned to the bottom edge:

![Loading screen on a phone](loading-screens/phone.png)

The status line says what it's waiting on: *Loading the game*, *Heading to the
Outpost*, *Loading the area*, *Landing*, and so on. The bar shows real progress
while joining and sweeps otherwise. Tips rotate every five seconds. The screen
takes clicks and taps, so nothing behind it is pressed by accident.

## Tips, by how far you've got

The tips change as you play (`LoadingScreen.Tips`). Your save puts you in one
of three stages (`LoadingScreen.stage`, fed by `LoadingFlow.progress` each time
your profile updates):

| Stage | Who | Tips, newest to you first |
| --- | --- | --- |
| 1 Just started | no gem mined yet, under 10 rocks | mine gems to upgrade your gear and unlock moves · sword gem = Q, core = E, shield = R · land hits for Charge · parry (raise your guard just before a melee hit) · Crystal Boulders hold gems more often, and rarer ones |
| 2 Found a gem | first gem mined, or 10+ rocks | rarity sets how strong a gem's moves are (Common 60% to Legendary 100%, plus a Flourish) · grades 1–10: Size power, Clarity duration, Cut cooldowns and odds · Thermal > Cryo > Ion > Corrosive > Thermal · then the stage 1 tips, minus Charge |
| 3 Old hand | level 5, 5 fights or 150 rocks | 2, 4 or 6 pieces of one set (the sword counts) · Ranked evens stats and caps gems at Ultra Rare · then the stage 2 tips and parry and rocks (the basics stop) |

A tip shows from its `Stage` up to its `Last`, if it has one. A new stage
starts its tips from the top. Until your save has loaded (the very start of
joining), you get stage 1. Every tip is in the Spanish table, and the test
keeps each one short enough for its two lines.

## When it shows

| Moment | Up until |
| --- | --- |
| Joining (from the very first frame, in place of Roblox's own) | the game is loaded, your miner has spawned, and the title screen is built with its art and music downloaded; at least 1.2 s |
| CLICK TO ENTER on the title | the starter intro is up with its images downloaded, or you're standing in the Outpost |
| The starter intro closing | your first fight's drop screen takes over, or you're in the Outpost |
| Going to the Outpost (lobby, unstuck, after the mine) | you're in the basin, on loaded ground, with the camera on you |
| A fight ending | you're back in the Outpost |
| A duel, raid or dungeon starting | you're in place (the Arena's own drop already has its own screen, so not that) |
| Respawning | you're back in the Outpost |
| The mine, down and back | you're standing in the mine, or back in the Outpost |
| Any other jump of 100+ studs in one frame | you've landed and the area round you has loaded |

## What "ready" means

What's behind counts as ready once it is either:

- a full-screen view of its own: the title, the intro once its images are
  down, or the Arena drop's screen; or
- the world, with all of these true: you're alive and somewhere you belong
  (the Outpost, a fight, the mine), within 80 studs of where you were headed,
  standing on loaded ground, with the camera on you, not still being moved,
  and the area's downloads finished (or 2.5 s spent waiting on them).

Every cover stays up at least 0.8 s and at most 12 s, so a stuck scene can't
hold you behind it.

## Where it lives

- `src/first/LoadingScreen.luau` (ReplicatedFirst): the screen itself, and the
  covers that want it up.
- `src/first/Loading.client.luau` (ReplicatedFirst): joining.
- `src/client/Modules/LoadingFlow.luau`: when each scene is ready. The other
  moments are watched by `LoadingFlow.start()`, run from `Lobby.client`.
- Scenes ask for it directly: the title (`Splash.client`), the intro
  (`Intro.client`), `OutpostScene` and `MineScene`.

It never stands in the game's way. If `ReplicatedFirst.LoadingScreen` is
missing from the place (for example, Rojo was already running when the project
file gained it, so it never synced) or it breaks, the game starts and runs
exactly as before, just without the cover. The console then says
`[LoadingFlow] no loading screen …`. In Studio, ReplicatedFirst should hold
`Orientation`, `LoadingScreen` and `Loading`; if it doesn't, restart
`rojo serve` and reconnect. A screen that errors while it's up takes itself
away.

To cover something new:

```lua
local cover = LoadingFlow.hold("Mine", { FadeIn = 0.25, Destination = LoadingFlow.home })
LoadingFlow.waitCovered(1) -- before moving anything
-- ...move the player; if the request fails: cover.cancel()
```

Tests: `tests/run_loading_screen.py` (lune).
