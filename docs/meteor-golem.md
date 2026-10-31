# The Meteor Golem

A new miner's first boss, once.

## When it comes

Ten seconds after a player's first swing at a rock in the Outpost, a meteor
comes down about 30 studs ahead of them. It only comes if:

- their intro is done,
- they've never beaten it, and
- nothing else is on: no fight, match, dungeon, mech or kaiju battle.

If they walk away from it or go down, it sinks back into its crater. It comes
again at a swing a minute later.

## The cinematic

The beats, in seconds from the meteor's start (`Shared.MeteorGolem`):

| Beat  | Time | What happens |
|-------|------|--------------|
| Fall  | 3    | The meteor lands: flash, shake, a crater with a glowing rock in it. |
| Crack | 3.9  | The rock's magma cracks flare. |
| Rise  | 4.8  | The rock bursts and the Magma Golem climbs out. The name card shows. |
| Awake | 6.6  | The fight's on. The camera eases back to the player and their kit comes out. |

The player stands still through it, in letterbox bars. Everyone nearby sees
the meteor fall; only that player gets the camera.

- Client: `Client.MeteorGolemFx`
- Server: `Server.MeteorGolemServer`
- Remote: `Remotes.MeteorGolem`, with events `Fall`, `Blow` and `Fell`

## The fight

It's easy, but not that easy. The golem has 1500 HP, walks slower than you,
and throws a blow every 2.6 s. Every blow is telegraphed by a red ring on the
ground first:

- **Slam:** when you're within 11 studs. Both fists come down after a 1.15 s
  warning, in a 9-stud ring. It deals 20% of your max health.
- **Rock:** when you're within 45 studs. It lobs a molten rock where you stand
  after a 1.3 s warning, in a 6-stud ring. It deals 14% of your max health.
  It never throws three Rocks in a row; it closes in instead.

It's an Outpost creature, so your kaiju fight it too. It's Fire, weak to Frost.

## The reward

The cache is a threat I boss cache (`ArenaStreaks.bossCache`): two pieces of
gear, at least Uncommon. You keep one, and the other goes to the Market.

There's no kaiju roll (`{ NoKaijuRoll = true }`). Beating it sets
`profile.Milestones.MeteorGolem`, so it never comes again.

## Tests

`tests/run_meteor_golem.py`
