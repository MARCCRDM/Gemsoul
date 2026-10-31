# The Kaiju Daycare

A pen in the Shelter's hall, east of the Kennel's stage, where you board kaiju
you aren't using. Its kaiju wander the pen for everyone in the server to see.
Each has a plate over it: its name and level, its owner, and **TRAINING** or
**STORED**.

To open it, use the keeper's desk in front of the pen (prompt: **Kaiju Daycare**).

## Boarding

Pick one of your kaiju at home. It can't be the team that's out or your
support (the Market's rule for a kaiju leaving the roster), and it can't be
knocked out. Then pick:

- **STORE**: kept safe for 25 coins an hour, at most 3,000 a stay. It's out
  of your roster, so it doesn't count toward the 24-kaiju limit.
- **TRAIN** for 1, 4, 12 or 24 hours. Training costs 60 + 12 × its level
  coins an hour, fixed at the level it came in at. Each hour it gains 15% of
  what its level needs (`Kaiju.expToNext`), about a level every 6–7 hours,
  up to **level 20**. When the hours are up, or it reaches level 20, it's
  kept at the STORE rate until you collect it.

The window shows the cost before you board, and for TRAIN the level it will
reach (`DaycareUI.project`, the same sums as the server's).

You can board 3 kaiju at once (`Daycare.Slots`).

## Collecting

**COLLECT** pays what it owes and gives it back. It comes back trained, at
full health, at the end of your line, with a new id.

- **Short of coins:** it waits, safe.
- **24 kaiju already:** make room first, with LET GO or the Market.

| Example | Fee |
|---|---|
| Store, a day | 600 |
| Train level 5, 4 h | 480 |
| Train level 10, 12 h | 2,160 (to about level 12) |
| Train level 15, 24 h | 5,760 |

## How it works

| Part | Where | What it does |
|---|---|---|
| The rules | `Shared.Daycare` | Fees, training and the pen's place. Nothing ticks: everything is worked out from when the kaiju came in (`Daycare.result`). |
| The server | `Server.DaycareServer` | Handles `DaycareState`, `DaycareBoard` and `DaycareCollect`. A boarded kaiju leaves the roster through `Market.take` and waits in `profile.Daycare.Entries`. It comes back through `Market.give`. The fee is coins spent as `"Daycare"` (Analytics: Shop). |
| The pen | `Client.DaycarePen` | Built on each player's screen, and mounted, shown and stepped by `KennelLife`. The server keeps who's in it in `ReplicatedStorage.DaycarePen`, the boarded kaiju of the players in this server, at most 12 drawn. They wander like the Kennel's (`KaijuKennel.state` with `Daycare.Pen`). |
| The window | `Client.DaycareUI` | Boarding, the price shown up front, and collecting. |

## Next: offers

Next, other players will be able to make offers on boarded kaiju, through the
Market's offers and escrow, so nothing can be duplicated.

## Tests

`tests/run_daycare.py`
