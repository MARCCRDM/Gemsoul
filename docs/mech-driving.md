# Driving the mechs

The Outpost's Motor Pool has eight mechs of four kinds (Atlas Hauler, Mole
Drill, Forge Utility and Scout Pathfinder). Walk up to one and hold **E**
("Pilot") to climb into the cockpit. To drive:

- **W / S** (or the arrow keys) to go forward and back;
- **A / D** to turn. The mechs turn on the spot;
- **Space** to hop out.

A gamepad's left stick and the phone thumbstick work too. A card at the bottom
shows the mech, its speed and the controls. An empty mech walks itself back
to its bay after 90 seconds.

![Mech lineup](mechs/mech-lineup.png)

## How it works

Each mech slides on one invisible chassis. A `LinearVelocity` called `Drive`
sets its speed over the ground, and an `AlignOrientation` called `Steer` sets
its heading. Everything else is massless bodywork on joints, animated by
`MechAnimation`. The driving maths is `Outpost.drive` in `src/shared/Outpost.luau`.

Normally the pilot's own client runs the physics, so the mech handles with no
lag. When you sit down, the server hands you the chassis's physics, and
`VehicleDrive` sets `Drive` and `Steer` every frame from your input.

## Why it can't get stuck any more

Before, a mech could take the pilot but not move. There were three ways this
could happen, and each one is now covered:

| What went wrong | What happens now |
| --- | --- |
| The seat's throttle and steer stayed at 0. Roblox's controls fill them from WASD, but they can be switched off by another scene, or be slow to notice the seat. | `VehicleDrive` falls back to the controls' move vector, then to the keys themselves: W/S/A/D and the arrows, ignored while you type in chat. |
| The hand-over of the physics never took, or was lost. | The server retries 0.5 s after you sit, then every 2 s. The first failure prints one warning in the output: `[Mech] <kind>: couldn't hand its physics to <player>, the server drives it instead: <reason>`. |
| The server still runs the physics, so the client's settings for `Drive` and `Steer` do nothing. | The client also sends its input to the server (`MechInput`): when it changes (at most 10 times a second), every 0.5 s while held, and 0 straight away when you let go, open a menu or get out. Whenever the server holds the physics it drives the mech itself, with the same maths and the same wall rule. It picks up from the mech's current heading and speed. |

The server only accepts input from the player sitting in that seat. It takes
real numbers only, clamped to -1..1. Input that stops arriving for 1.5 s counts
as let go, so a dropped connection doesn't leave a mech driving off. A pilot
who enters a fight, an expedition or an Arena drop stops driving, and the next
pilot starts from rest.

| Piece | What it does |
| --- | --- |
| `src/server/World/OutpostMachines.luau` | Builds each mech: chassis, bodywork, seat, `Drive` and `Steer` |
| `src/server/Systems/OutpostVehicles.luau` | Parks the mechs, runs the Pilot prompt and the physics hand-over (with retries), accepts `MechInput`, and drives from the server when it has to. Sends empty mechs home |
| `src/client/Modules/VehicleDrive.luau` | Your input (seat, then controls, then keys), driving each frame, sending input to the server, the driving card and camera |
| `Remotes.MechInput` | Client to server: `(throttle, steer)` |

## Verification

- `tests/run_outpost_vehicles.py` (48 checks) runs the real server module and
  driving maths with stand-in seats, players and physics. It covers boarding;
  the hand-over; staying out of the way while the client drives; a failed
  hand-over, with the server driving to top speed, steering, the wall rule,
  lost input, a busy pilot, retries, the hand-over taking and the warning
  appearing once; picking up the current heading; getting out; a new pilot
  starting from rest; whose input counts and bad numbers; and an anchored mech.
- `tests/run_vehicle_transition.py` (62 checks) covers the client: the
  fallback input from the seat, then the move vector, then the keys; arrows;
  no driving while typing; what is sent to the server and when, at most 10
  times a second from a sweeping stick; and stopping for menus and getting
  out.

Each of 23 deliberate breaks in these pieces is caught by these checks.

Not yet checked in Studio. If a mech still won't move, look in the output for a
`[Mech]` warning: it names what blocked the hand-over.
