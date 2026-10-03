# Brainrot squad dungeons — playable implementation

## Entering a run
Form a party of three or four in Social. Every member marks Ready; the leader selects **DUNGEON**. Queueing is server-validated. Living characters must be out of mining expeditions, duels and existing combat sessions. The roster is locked at deployment; there is no mid-run join.

Five connected rooms are generated per run. Layout turns, room themes, pillar counts and fighter composition change. Each of the first four rooms has two or three fighters. Defeat them to open the next gate. Surviving players recover health and combat resources at each checkpoint. The fifth room has one Colossus: a 1.8× version of a selected roster character.

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

All three boss Surge slots use its main element at tiers 2/3/4 and rank III. Regular fighters use lower-tier, rank-I Surges. Each archetype has a fixed maneuver pool. The Colossus has increased health and damage over its regular fighter version. The existing AI currently chooses one squad member at a time; this is not a new raid-wide threat/pathfinding system.

A cleared dungeon gives each surviving, still-enrolled player **300 coins and SlayBrute XP**, once. There is no additional gem loot in this first implementation. There is no revive or checkpoint resurrection system. Failed runs grant no completion reward.

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
- `src/server/Systems/BrainrotSkins.luau`: animated creature geometry.
- `src/client/Dungeon.client.luau`: first-person objective strip.
- `tests/run_dungeons.py`: deterministic lifecycle/layout tests.
