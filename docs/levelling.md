# Levelling up

Your level is the one on your card in the lobby (your miner's level,
`Shared.AugmentTree`: each one brings an augment point and more health).
It comes mostly from **beating things**: the bosses of the Rift and the
dungeons, party raid waves, arena rivals, other players in duels and kaiju
battles. A win is worth more the higher the foe's level is over yours, and
less the further it is under. **Mining** gives a little, less and less the
more you've mined lately, so it helps you along but you can't level on it.
It's **yours alone**: your kaiju get nothing for your rocks (they level by
fighting).

The rules are in `Shared.Levelling`. `Server.Progress` pays them out:
`Progress.won` for a win, `Progress.mined` for a rock.

## Mining: less the more you mine

A rock is worth `Base * Half / (Half + mined)` XP, never under `Floor`.
`mined` is how many rocks you've broken lately; it halves for every `Rest`
seconds that pass (`Levelling.Mine = { Base = 10, Half = 20, Floor = 1,
Rest = 1800 }`).

| Rock in a row | XP for it | All told |
| --- | --- | --- |
| 1st | 10 | 10 |
| 10th | 7 | 83 |
| 20th | 5 | 141 |
| 50th | 3 | 254 |
| 130th (a full charge) | 1 | 409 |

A full free charge used to be 1,950 XP at a flat 15 a rock. It's now about
400. Mine on and on and it settles at 1 a rock. Stop for half an hour and
what you've mined lately halves: after a full charge, two hours off and the
next rock is worth 7 again, four hours and it's 10. The count is kept in your save (`profile.Levelling
= { Mined, At }`), so rejoining doesn't reset it.

The same amount goes to the Season Path (`Season.XP.Mine`, 10, is a rock's
most). Every rock goes through `Progress.mined`: the Outpost's
(`OutpostServer`), the old gem nodes (`Mining`) and an expedition's wall
(`MineWall`).

**Your kaiju get nothing for it.** `KaijuServer.mined`, `Kaiju.MineExp` and
the `OutpostServer.onRockMined` hook that fed them are gone. They still
level while you mine by fighting the critters your swings bring out.

## Wins: by the foe's level

A win is worth a share of what your next level takes
(`AugmentTree.xpToNext(level)`), at your own level:

| Win (`Levelling.Share`) | Share | At level 5 | At 10 | At 20 |
| --- | --- | --- | --- | --- |
| A Rift's boss (`RiftBoss`) | 0.6 | 292 | 706 | 2,074 |
| A dungeon cleared (`DungeonBoss`) | 0.5 | 243 | 588 | 1,728 |
| A duel won (`DuelWin`) | 0.3 | 146 | 353 | 1,037 |
| A kaiju battle won (`KaijuWin`) | 0.15 | 73 | 176 | 518 |
| A raid wave cleared (`RaidWave`) | 0.15 | 73 | 176 | 518 |
| An arena rival beaten (`Rival`) | 0.1 | 49 | 118 | 346 |
| A duel lost or drawn (`DuelPlay`) | 0.04 | 19 | 47 | 138 |
| A kaiju battle lost or drawn (`KaijuPlay`) | 0.02 | 10 | 24 | 69 |

Then it's multiplied by the **gap**: about 1.15x for each level the foe is
over you, and divided by 1.15 for each level under, kept between a fifth
and three times (`Levelling.Gap`):

| Foe vs you | 12 under | 8 under | 5 under | 3 under | even | 3 over | 5 over | 8+ over |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| x | 0.2 | 0.33 | 0.5 | 0.66 | 1 | 1.52 | 2 | 3 |

So a Rift boss five over you at level 10 is 1,419 XP, and one five under is
351. The level a foe stands at:

| Win | Foe's level |
| --- | --- |
| Rift boss | the boss's level, as shown (`run.BossLevel`, `RiftRun.bossLevel`) |
| Dungeon | the squad's average level (its boss has no level of its own) |
| Raid wave | the raiders' average level, plus one for each wave after the first |
| Arena rival | yours (a rival is built to match you) |
| Duel | the other side's average level |
| Kaiju battle | the other player's level |

**The same player again.** Beat the same player again within the hour and
it's worth half, then a quarter, and so on, never under 1 XP
(`Levelling.Again`). A different player is worth all of it, and an hour on
the first one is too. This stops two friends trading wins for levels.

The Season Path still pays a win its usual Season XP (`Season.XP`: a duel
won 40, lost 15; a boss, a dungeon, a raid wave or a rival 35 as
`SlayBrute`). Kaiju battles pay none, as before. The messages say what a win
gave: "*boss* is beaten! +*coins* coins, +*XP* XP…" (the Rift), "Victory! You
defeated *rival*: +*coins* coins, +*XP* XP…" (the arena) and "… +300 coins,
+*XP* XP." (a dungeon cleared).

## Bosses, not rocks

From level 8 on, one Rift boss at your level is worth more than a whole
charge of rocks, and so is one duel won against a player five over you. By
level 20 a full charge is under a fifth of a level. A brand-new miner still
gets going by mining: the first level takes a few dozen rocks.

## Where it lives

| | |
| --- | --- |
| `src/shared/Levelling.luau` | The rules: `Mine`, `rested`, `mineXP`, `Share`, `Gap`, `gap`, `Again`, `winXP` |
| `src/server/Systems/Progress.luau` | `Progress.mined(player)`, `Progress.won(player, kind, foe, season?, rival?)`, `Progress.levelOf(player)`; `Progress.addXP` for the rest (selling, socketing, daily rewards, kills) |
| `Duels`, `Duelist`, `Dungeons`, `RiftServer`, `KaijuBattles` | The wins, each with its foe's level |
| `OutpostServer`, `Mining`, `MineWall` | The rocks |

## Tests

| Suite | Covers |
| --- | --- |
| `run_levelling` | The rules: rocks falling off and coming back with rest, settling at 1; the gap and its bounds; every share at every level; the same player again; bosses outpacing mining from level 8; the first level from mining; every source wired to them, and nothing from your rocks to your kaiju |
| `run_combat` (`augment_cases`) | The real `Progress`: a rock's XP to your level and the Season, falling off, kept in the save, back after a rest; a Rift boss's share by its level; a higher boss over a lower one; the same rival halved, another not, an hour on not; nothing for an unknown win or past the level cap |
| `run_duels` | A duel's XP by the other side's level, the Season's by the result, the one beaten named |
| `run_kaiju` | Mining gives your kaiju nothing; a kaiju battle's XP for both players by the other's level; a Rift boss's by its level, said with the win |
| `run_outpost` | A popped rock gives its miner XP once, and no hook to their kaiju |
