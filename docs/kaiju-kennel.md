# The Kaiju Kennel

The stage in the middle of the Shelter's hall used to carry a hologram of
a kaiju. It's the **Kaiju Kennel** now: a fenced pen where the rarest kinds
of kaiju wander about, with **Wren**, the kennel keeper, at the gate.

## The hologram

Switched off, not deleted: `ShelterLife.Hologram = false`
(`src/client/Modules/ShelterLife.luau`). With it off the hologram, its
name plate and its projector console are taken out of the world and never
posed. Set it to `true` to bring it back somewhere else.

## The pen (`src/server/World/OutpostWorld.luau`)

On the old stage: a bed of packed earth, a rock to climb in the middle,
troughs by the fence, a fence of 28 posts with two rails between each pair
(it collides: players stay outside), and a **KAIJU KENNEL** arch over the
gate, facing the hall's main door.

## Who lives there (`src/shared/KaijuKennel.luau`)

- **Residents**: six kinds a day, all from the rarest batch (the first 30
  kinds after the starters, `Kaiju.batch == 1`), each in an element of its
  own. They change at midnight, server time.
- **Kaiju of the Day**: one more kind of that batch a day, never one of
  the residents. It stands on its own display in front of the gate (see
  the Kaiju of the Day).
- **What they do**: each resident has a wedge of the pen to itself, so two
  never walk into each other. Every few seconds it either walks to a new
  spot in its wedge (turning to face the way first) or stays put and
  sniffs the ground, looks about, lies down, sleeps or roars.

All of it comes from the day and the server's clock, so every player sees
the same kaiju doing the same thing at the same moment, and the server
sends nothing. `Kennel.state(index, count, now)` gives a resident's spot,
facing, speed and mood at any moment.

## Drawing them (`src/client/Modules/KennelLife.luau`)

Each client builds today's residents from `KaijuModels` (at 0.75 scale),
with nothing on them that can be touched, clicked or hit, and moves them
30 times a second while you're near the Shelter. `CreatureAnimation` poses
them like any kaiju: their legs walk at the speed the kennel says
(`PacedSpeed`), since they're moved rather than pushed, and their moods are
the wild kaiju's (`KaijuMood`).

## Wren (`Vendors.KaijuKeeper`)

By the gate, facing the door:

- **Who's in the pen today?** names today's six.
- **Buy and sell kaiju** opens the Market on kaiju.
- **Kaiju and their kinds**: why these are rare, how to get one, selling.
- **Give me a tip**: kennel and kaiju tips.

## Tests

`tests/run_kaiju_kennel.py`: residents and the Kaiju of the Day by day
(rarest batch, no overlap, changing daily, cycling through the batch),
every resident inside its wedge and the pen, no jumps or spins, every mood
seen, no two ever touching, and every client working out the same. Also
the pen in the world, Wren and her options, the hologram off, and the
animation hooks.
