# Brainrot squad dungeons — playable implementation

## Entering a run
Form a party of three or four in Social. Every member marks Ready; the leader selects **DUNGEON**. Queueing is server-validated. Living characters must be out of mining expeditions, duels and existing combat sessions. The roster is locked at deployment; there is no mid-run join.

Five connected rooms are generated per run. Layout turns, room themes, pillar counts and fighter composition change. Each of the first four rooms has two or three fighters. Defeat them to open the next gate. Surviving players recover health and combat resources at each checkpoint. The fifth room has one Colossus: one of the ten bosses (`DungeonRules.Bosses`, most of them two- or three-headed), at 1.8×; see [bosses-and-swarms.md](bosses-and-swarms.md) and, for their bodies now, [boss-titans.md](boss-titans.md). An open expedition's middle camp is one of them too.

At least three survivors must reach the boss encounter. Losing a member after the boss has engaged does not reset the boss. Leaving the party, leaving combat, respawning, a full squad wipe, or the 15-minute limit removes the appropriate participants and cleans up empty runs. Up to eight isolated squads can run concurrently.

## First roster
These are new procedural Roblox adaptations attached to the existing R15 combat skeleton. They are not imported meshes or polished final character art.

| Character | Main element | Weakness | Silhouette and role |
|---|---|---|---|
| Tung Tung Tung Sahur | Thermal | Cryo | Wooden bruiser with bat and hydraulic slams |
| Tralalero Tralala | Cryo | Ion | Shark face, dorsal fin and blue sneakers; quick flurries and dodge |
| Brr Brr Patapim | Corrosive | Thermal | Tree creature with long nose, branches and canopy; heavy disruption |
| Bombardiro Crocodilo | Ion | Corrosive | Crocodile snout, teeth and bomber wings; ranged pressure |

Incoming damage from the main element is reduced 30%; the weakness deals 30% more. Other elements and physical damage are neutral before normal armor/guard mitigation. Weapon elemental hits, direct Surges and Thermal burns pass their element explicitly. The nameplate lists the main element and weakness.

Character references: [Tung Tung Tung Sahur and related characters](https://knowyourmeme.com/memes/tung-tung-tung-sahur), [Brr Brr Patapim](https://knowyourmeme.com/memes/brr-brr-patapim). Elements, roles and combat tuning above are this game's design choices.

## Combat reuse
Dungeon fighters use `Duelist.spawnDungeon`, the existing `DuelistBrain`, `RivalPose`, leg animations, server combat damage, Stamina/Charge, guards, parries, dodges, charged strikes, and telegraphed Surges. Creature geometry is welded to the same animated bones. Dungeon actors have their own registry so several fighters can operate concurrently without replacing a player's Arena rival.

All three boss Surge slots use its main element at tiers 2/3/4 and rank III. Regular fighters use lower-tier, rank-I Surges. Each archetype has three fixed moves: a room fighter has its signature move and two rig maneuvers, and a boss has three moves of its own, one a big telegraphed attack ([creature-moves.md](creature-moves.md)). The Colossus has increased health and damage over its regular fighter version. The existing AI currently chooses one squad member at a time; this is not a new raid-wide threat/pathfinding system.

A cleared dungeon gives each surviving, still-enrolled player **300 coins and SlayBrute XP**, once, and a **boss cache** of their own: two pieces of gear to keep one of, like every reward, the other to the Market from the Rift Vault (see [arena-streaks.md](arena-streaks.md#boss-caches)). The run ends five seconds after the boss falls; the cache waits to be opened. There is no revive or checkpoint resurrection system. Failed runs grant no completion reward.

## The fallen

Each room has a fallen miner of a crew that went in before, by a wall: a
real miner (the fighter rig in a random kit, a random suit or skin on some,
`Server.Systems.FallenCrew`), its spilt gems glowing the room's element; the
boss's room has 4 and their heap beside the boss (old helmets on spikes, a
torn banner). Props only, built with the room (`Server.World.FallenMiners`;
see [rift.md](rift.md#the-fallen)).

## Verification and remaining playtest
- 1,000 seeded layouts checked for uniqueness and connected room order.
- Server lifecycle tests cover party size, readiness, leader authority, duplicate queue attempts, concurrent isolation, gate progression, final boss requirement, one-time rewards, failed spawns, early exits and timeout.
- Existing combat, technology, Augment, Duelist rule/pose, duel and raid suites pass.
- Luau compilation and Rojo place build pass.
- Roblox Studio multiplayer playtesting is still required. Check navigation around pillars, creature proportions, locomotion and hit poses, boss reach, mobile HUD placement, streaming and difficulty with three and four players. Offline tests do not prove these visual/runtime details.

## Key files
- `src/shared/DungeonRules.luau`: roster, requirements, elemental rules and procedural path.
- `src/server/World/DungeonWorld.luau`: connected rooms, lamps, corridors and gates.
- `src/server/Systems/Dungeons.luau`: queue, session authority, progression and cleanup.
- `src/server/Systems/BrainrotSkins.luau`: animated creature geometry (the room fighters).
- `src/server/Systems/BrainrotBosses.luau`: the ten bosses' bodies.
- `src/client/Dungeon.client.luau`: first-person objective strip.
- `tests/run_dungeons.py`: deterministic lifecycle/layout tests.

## Raid squad recruitment

The raid button opens Social with a three-slot squad card: the local player and two open teammate slots. Invite Friend opens Roblox's game invitation prompt; once the friend joins the server, use + Party in the player list. Existing party readiness, kicking and leaving remain available.

Fill Random searches among opted-in players in this server. It assembles three solos or a ready duo plus a solo; friend groups are never split. The leader queues a friend party after all its members mark Ready. Selecting random search consents to automatic dungeon deployment when three are matched. Anyone in a searching group can cancel it. Party changes, readiness changes, disconnects and entering another combat activity invalidate the search. Start Party remains the manual ready-party launch, including existing four-person parties.

This implementation does not match across Roblox servers. Developer solo test controls remain separate from public matchmaking.

Validation: tests/run_dungeon_queue.py executes the actual Party and DungeonQueue modules using deterministic service doubles. Covers invitations, three solos, duo plus solo, leader/readiness restrictions, duplicate queue and launch prevention, cancellations, disconnects, occupied players, and preserving existing parties.

## The Rot Beachhead (the campaign's first dungeon)

The new player's first dungeon, after the intro fights (the New Player Pipeline proposal). It's reached from the intro rounds' card (**FIRST DUNGEON**, beside GO TO LOBBY, and TO THE FIRST DUNGEON once the set's done) and from the DEV panel's **FIRST DUNGEON (NEW INTRO)**. **It's off for now** (`Config.Features.FirstDungeon = false`): hidden on the card and the DEV panel, and the server refuses it for everyone, owners too. Switch it on to bring it back for every player (the `FirstDungeon` request). Either way it plays as a new player would:

1. The kaiju roll, if one is owed (Client KaijuRoll).
2. The loading screens (Client FirstDungeonUI): YOUR KAIJU (your team out; "Your kaiju will defend you and heal you"), then the scout mission. A tap skips one.
3. In: `DungeonTest "First"`. It's solo, with a pod drop, and your kaiju are let in (the `DungeonKaiju` attribute; Server KaijuServer) and fight the room's fighters (`KaijuFoes`, flagged as `OutpostCreature` targets).
4. Room 1: The Gate (Sahur). Room 2: The Yard (Tralalero, Patapim). The Nest: the boss. All of it is in a straight line, with rot pods, growths and hull plates round each room (DungeonWorld.dressBeachhead).
5. The boss down: a boss cache. Out after 6 s, with a clear's coins and XP.

Shared.DungeonRules.First holds its numbers. The fighters are at 50% health and 60% damage; the boss is at 60% health and 80% damage. All of it hits softer the fewer intro pieces you've won (`firstDamage`: x0.75 with one, x1.0 with six).

A lethal blow knocks you down instead (shielded, the Outpost's knock-down). After 3 s the card comes up:

- **RECOVER** puts you back at the start of the room you fell in, at full health. The room's fighters are back at full too (`Duelist.healDungeon`). After 30 s it recovers you by itself.
- **FINISH THE INTRO FIGHTS (n LEFT)** shows only while intro rounds are left to win. It takes you out, with no rewards, and on into the next round.
- **GO TO LOBBY** takes you out to the Outpost, with no rewards.

The same ways out are on **LEAVE** (top right, any time in the dungeon), with STAY to carry on (`FirstDungeonQuit`, "Intro" or "Lobby").

The boss is Chimpanzini for now, standing in for Granchio Rottamino, whose model is still to come. After the dungeon you go back to the Outpost: the mining / socket / kaiju / critter steps that follow it aren't built yet.

Tests: `tests/first_dungeon_cases.luau` (in tests/run_dungeons.py), and the Rot Beachhead's screens and card in tests/client_extras_boot.luau.

### Its look, tracker and ending

- **Look:** the rooms are built in the Rot theme (`World.build(..., "Rot")`): wet black sand, the invaders' hull for walls, rot-green lamps and crystals, violet membrane gates. `World.dressBeachhead` adds rot pods, growth, glowing tendrils, slime pools, drifting spores and hull plates to every room. In the Nest it adds a rot stain, a ring of growth and egg sacs, with the crashed ship's nose behind. The client lights it with `ArenaNight.RotMood`: dusk, green-violet haze, bloom on the glow.
- **Tracker** (Client FirstDungeonUI, top right): the three rooms, what to do now, and the latest word. It follows the server's `DungeonPhase` ("Fight" / "Move" / "Loot"), `DungeonFoesLeft` and `DungeonFoesTotal`. A cleared room puts a beam over the next one (`World.beacon`: NEXT ROOM, THE NEST).
- **The boss** enrages at half health and its rot-spawn join in (`Rules.First.Enrage`). The loot waits until they're down too.
- **Ending:** a victory card after the boss cache shows the time, knock-downs and coins. It offers FINISH THE INTRO FIGHTS (while rounds are left) or BACK TO THE OUTPOST (`FirstDungeonDone`, with the clear's rewards). After `WinSeconds` (25 s) it heads out by itself.
- **Errors** in a run (setup, an encounter, the dressing, the beacon) go to the server's output and to an owner's screen as `[Dungeon] ...`.
