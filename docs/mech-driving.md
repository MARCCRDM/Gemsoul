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

The server moves the mechs itself. A mech isn't a physics body: it's
anchored, and each frame the server puts it where it should be. That's
`OutpostVehicles.step`, on the server's Heartbeat. The pilot rides along in
the seat. Nothing depends on Roblox handing the physics to anyone, on
constraints pushing it, or on the pilot's humanoid. An anchored part always
goes where it's put.

Mechs used to be driven through physics: a `LinearVelocity` set their speed
and an `AlignOrientation` their heading. Pilots kept reporting mechs that
wouldn't move, and no cause was ever found from the logs. So the physics
drive is gone.

Each frame, for a mech with a pilot, the server:

1. works out its speed and heading from the pilot's input. The maths is
   `Outpost.drive` in `src/shared/Outpost.luau`, as before;
2. sweeps the mech's **hull** ahead along that heading (`workspace:Blockcast`)
   and stops it 0.4 studs short of anything solid. Players, creatures and
   rifts don't count;
3. looks down for the ground where it's going (`workspace:Raycast`). It steps
   up anything up to 1.6 studs high (times the mech's scale), like a kerb or
   the Motor Pool's apron. It won't go up a higher ledge, or where there's no
   ground at all. Off a drop, it falls, under gravity;
4. keeps it inside the crater rim;
5. sets the chassis's `CFrame`. The whole mech moves with it, pilot and all.

Against something in the way, it stops dead. It starts again from rest when
you turn or back away. An empty mech stays put. One left in the air when its
pilot got out still lands.

The model carries where the server has the mech, for every client:

- `MechPosition`: where it is;
- `MechMotion`: its heading, speed and turn rate (X, Y, Z);
- `MechBlocked`: what's in its way, if anything. That's the part's name, or
  `a ledge`, `no ground` or `the crater rim`.

They're only sent when they change, so a mech standing still sends nothing.

The server's steps reach each client unevenly. So between steps,
`MechAnimation` carries the mech on from the latest step for up to a quarter
of a second, and eases out any difference. If it's more than 12 studs off,
it jumps there instead. It does this before the camera moves, so the pilot's
view is smooth too. Once the mech stops, it's put exactly where the server
has it and left alone. The legs walk at the server's speed.

Each mech's parts:

- **Chassis**: an invisible box, the model's PrimaryPart. It's the part the
  server anchors and moves.
- **Hull**: an invisible box from 1.6 studs up. It's what's swept ahead, so a
  kerb under it doesn't stop the mech.
- **Foot**: an invisible ball underneath. You can't walk through it.
- Everything else is bodywork on joints, animated by `MechAnimation`.

The pilot's game (`VehicleDrive`) reads the input and sends it with
`MechInput`. It sends it:

- when the input changes (at most 10 times a second);
- every 0.5 s while it's held;
- straight away as 0 when you let go, open a menu or get out.

The server only takes input from the mech's pilot, as real numbers clamped
to -1..1. Input that stops arriving for 1.5 s counts as let go. A pilot who
enters a fight, an expedition or an Arena drop stops driving. The next pilot
starts from rest. The driving card shows the speed the server moves the mech
at, and says when something's in the way.

## Seat discovery and boarding safeguards

Who sits in a seat is in two properties, `Seat.Occupant` and
`Humanoid.SeatPart`. Neither replicates: each side works them out for itself
(Roblox marks both NotReplicated). The Pilot prompt seats you from the server.
So your game could see no `Occupant` on the seat, and the server could see no
`SeatPart` on your body.

Every step of driving checked one of them:

- **Your game** only started driving when the seat's `Occupant` was you. If
  it never was, nothing was sent, and the mech never moved. Your game's own
  "won't move" report never ran either, because it only runs while driving.
  The only sign was one server warning: no word from the pilot's client.
- **The server** found the pilot's mech from their `SeatPart`. If that was
  empty, it refused every input, the stuck reports and the request to get
  out.
- **Mining from the cockpit** and the seated pose had the same problem.

The seat makes a weld, `SeatWeld`, from the seat (`Part0`) to your body's root
(`Part1`), and that weld does replicate. `Shared.Seating` answers "who sits
here" and "which seat is this body in" from `Occupant` / `SeatPart` when
they're set, and from the weld when they aren't. All of these use it now:
- `VehicleDrive` (starting, keeping on and stopping driving);
- `OutpostVehicles` (whose input counts, getting in and out, reports);
- `SeatExit` (hopping out);
- mining from the cockpit, on both sides;
- `MechAnimation` (the seated pose).

The server still never takes input for a mech someone else sits in.

The server also keeps a `PilotedMechSeat` ObjectValue on the player. This lets
the client find the exact seat when its local root joint list is incomplete;
it still verifies the seat occupant or weld before enabling driving. The
reference is cleared on exit. Heartbeat reconciles late weld endpoints, and
duplicate Occupant/SeatWeld notifications no longer reset accepted input.
These cases are covered by regression tests; they are not confirmation of
the cause of every live zero-speed report.

## When a mech still won't move

Both sides watch for it and say what they see:

- **Your game never starts driving.** When piloting starts, your game tells
  the server. If you've sat in a mech for 5 seconds and the server has heard
  nothing, it logs `[Mech] no word from the pilot's client`.
- **The mech won't budge.** You hold a direction for 2 seconds and the
  server's mech doesn't move (or doesn't turn, if you're only steering).
  - If the server says something's in the way, you're told to turn or back
    up.
  - If it still won't move after that, or nothing was in the way, your game
    prints `[Mech] Won't move (client): ...`. That line has your input and
    where it came from (seat, controls or keys). It also has where the server
    has the mech, its speed and what's in its way, and where your game has
    it. Your game sends that to the server and shows you a short message.

  The server logs `[Mech] <kind> won't move for <player>`, with both sides'
  view. Then for 1.5 seconds it drives the mech through whatever it's wedged
  in.

Each line goes to the Output, and the server's lines also go to Feedback →
Reports (owners only). A ride sends at most 2 reports from your game, and the
server takes at most 3. The next ride starts fresh. The server sends its own
view back to the pilot's Output too, so a client log shows both sides.

The seat's `MechInputThrottle` and `MechInputSteer` show the last input the
server accepted. Stuck reports include them.

| Piece | What it does |
| --- | --- |
| `src/server/World/OutpostMachines.luau` | Builds each mech: chassis, hull, foot, bodywork and seat |
| `src/server/Systems/OutpostVehicles.luau` | Parks the mechs (anchored) and runs the Pilot prompt. Takes `MechInput` and moves each mech along the ground. Sends empty mechs home |
| `src/shared/Seating.luau` | Who sits where, from the seat weld when the properties are empty |
| `src/client/Modules/VehicleDrive.luau` | Your input (seat, then controls, then keys), sending it to the server, the driving card and camera |
| `src/client/Modules/MechAnimation.luau` | Draws each mech gliding between the server's steps, and walks its legs |
| `Remotes.MechInput` | Client to server: `(throttle, steer)`. A `(0, 0)` when piloting starts says hello |
| `Remotes.MechReport` | Client to server: what your game sees when the mech won't move |
| `Remotes.MechExit` | Client to server: hop out (Space or jump) |

## Verification

- `tests/run_outpost_vehicles.py` (119 checks) runs the real server module
  and driving maths, with stand-ins for the seats and players. The world is
  a stand-in for the sweep and the ground. The checks cover:
  - driving, steering and top speed;
  - stopping short of a rock, and driving away again;
  - passing over a pebble and stepping up a kerb;
  - stopping at a ledge, falling into a pit, and refusing to drive into
    nothing;
  - the crater rim, and getting out mid-fall;
  - going home, seat replication, stuck reports and getting out.
- `tests/run_vehicle_transition.py` (91 checks) covers the client. That
  includes stuck detection from the server's position and heading, the hint
  when something's in the way, and the speed shown.
- `tests/run_mech_animation.py` checks the legs walk at the server's speed.
  It also checks the gliding: on from a step, catching up, jumping when far
  off, turning to the server's heading, and leaving a stopped mech alone.
- `tests/run_machines.py` and `tests/run_moon_quarry_scene.py` build every
  mech. They check the mechs have no drive constraints, only the foot and
  hull collide, and the hull starts 1 to 2 studs up.
- `tests/run_outpost.py` checks mining from the cockpit.

These run the real modules against stand-ins. Roblox's own `Blockcast`,
`Raycast` and replication can only be checked in a live server. If a mech
still won't move, hold W for a few seconds. Then copy every `[Mech]` line
from the Output, or from Feedback → Reports.
