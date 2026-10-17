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

Each mech is one physics assembly:

- **Chassis**: an invisible box carrying the mech's weight. It's the
  assembly's root and the model's PrimaryPart, but it doesn't collide.
- **Foot**: an invisible ball under it that touches the ground. A box sliding
  on its flat bottom catches on the smallest step (a kerb, the edge of the
  bay's apron) and stops dead. A ball rides up steps of up to 1.6 studs.
- **Hull**: an invisible box from 1.6 studs up, which hits walls.
- Everything else is massless bodywork on joints, animated by
  `MechAnimation`.

A `LinearVelocity` called `Drive` sets the mech's speed over the ground, and
an `AlignOrientation` called `Steer` sets its heading. The driving maths is
`Outpost.drive` in `src/shared/Outpost.luau`.

The server keeps the mech's physics. The pilot's game (`VehicleDrive`) reads
the input and sends it with `MechInput`. That happens when the input changes
(at most 10 times a second), every 0.5 s while it's held, and straight away
as 0 when you let go, open a menu or get out. Each frame the server sets
`Drive` and `Steer` from it. It only takes input from the mech's pilot,
real numbers clamped to -1..1. Input that stops arriving for 1.5 s counts
as let go. A pilot who enters a fight, an expedition or an Arena drop stops
driving, and the next pilot starts from rest.

## Why the mechs didn't move

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

## When a mech still won't move

Both sides watch for it and say what they see:

- **Your game never starts driving.** When piloting starts, your game tells
  the server. If you've sat in a mech for 5 seconds and the server has heard
  nothing, it logs `[Mech] no word from the pilot's client`.
- **The mech won't budge.** You hold a direction for 2 seconds and the mech
  never leaves the spot where you got in. Your game then:
  - prints `[Mech] Won't move (client): ...` with what it sees: the input and
    where it came from (seat, controls or keys), the speed, the drive
    settings, `ReceiveAge`, the assembly's root part and mass, and anything
    anchored in it;
  - sends that to the server;
  - shows you a short message.

  The server then frees anything anchored in the mech or your body and takes
  the physics back. It logs `[Mech] <kind> won't move for <player>`, with both
  sides' view and what it did.

Each line goes to the Output, and the server's lines also go to Feedback →
Reports (owners only). A ride sends at most 2 reports from your game, and the
server takes at most 3. The next ride starts fresh.

| Piece | What it does |
| --- | --- |
| `src/server/World/OutpostMachines.luau` | Builds each mech: chassis, foot, hull, bodywork, seat, `Drive` and `Steer` |
| `src/server/Systems/OutpostVehicles.luau` | Parks the mechs, runs the Pilot prompt, keeps the physics, takes `MechInput` and drives. Sends empty mechs home |
| `src/shared/Seating.luau` | Who sits where, from the seat weld when the properties are empty |
| `src/client/Modules/VehicleDrive.luau` | Your input (seat, then controls, then keys), sending it to the server, the driving card and camera |
| `Remotes.MechInput` | Client to server: `(throttle, steer)`. A `(0, 0)` when piloting starts says hello |
| `Remotes.MechReport` | Client to server: what your game sees when the mech won't move |
| `Remotes.MechExit` | Client to server: hop out (Space or jump) |

## Verification

- `tests/run_outpost_vehicles.py` (83 checks) runs the real server module and
  driving maths with stand-in seats, players and physics. Among them: a pilot
  the server sees only through the seat's `Occupant`, and one it sees only
  through the seat weld. Both drive, report and get out, and once out their
  input is refused.
- `tests/run_vehicle_transition.py` (85 checks) covers the client. Among
  them: a pilot whose game sees its own `SeatPart` but no `Occupant` drives,
  and so does one whose game sees only the seat weld.
- `tests/run_machines.py` (1760 checks) and `tests/run_moon_quarry_scene.py`
  build every mech. They check that only the foot and hull collide, that the
  foot (a ball) reaches the ground, and that the hull starts 1 to 2 studs up.
- `tests/run_outpost.py` checks mining from the cockpit.

These run the real modules against stand-ins. Roblox's own physics and
replication can only be checked in a live server: if a mech still won't move,
hold W for a few seconds, then copy every `[Mech]` line from the Output, or
from Feedback → Reports.
