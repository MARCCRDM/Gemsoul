# The Kaiju Daycare

A pen out in the quarry where you board kaiju you aren't using. Its kaiju
wander the pen for everyone in the server to see. Each has a plate over it:
its name and level, its owner, and **TRAINING** or **STORED**.

To open it, use the keeper's desk in front of the gate (prompt: **Kaiju Daycare**).

## Where

Walk out of the Shelter's main door, down the ramp, and turn right (west).
The pen is in the quarry's frame at (-70, 102), about 20 studs past the
ramp's edge. That spot is:

- inside the core, so no rifts
- between the Shelter's legs and the pumpkin patch
- off the roads and the landing pad

The server keeps 32 studs round it clear of rocks and wild kaiju, with the
ground flat (`DAYCARE` in `OutpostWorld`, which must match `Daycare.Pen`; the
crater that was there is gone). The tests check it against the ramp, the
Shelter's feet, the roads, the pad and the patch.

The pen itself, 32 studs across:

- a stone-edged lawn with a sand path ring
- a white rail fence
- a shade tree, flower beds, a water trough and hay
- the **KAIJU DAYCARE** arch over the gate (east, to the ramp), strung with lights
- a red barn behind it
- four lamp posts
- the keeper's desk under a striped awning, with a price board

Kaiju in it are full size (`Daycare.Scale` 1).

**The ground.** The quarry floor there is terrain, a little above the
quarry's frame, and it streams in. So the client builds the pen only once
there's ground under it: it raycasts down at its middle, round its fence and
at its desk, takes the middle height, and stands everything on that. Before
this, it was built at the frame's height and sat half sunk.

**The look (2026-10-31, second pass):**

- **Lawn:** a lawn with a sand path ring for them to walk, and a straw
  target on a stump in the middle.
- **Fence:** lanterns on every other post, bushes outside.
- **Inside:** two trees, a pond ringed with stones, flower beds, a trough,
  hay, and straw beds by the barn.
- **Way in:** stepping stones from the gate to the desk, and the desk's
  striped awning over its counter.
- **Plates:** dark rounded plates with the kaiju's element colour round
  them, a TRAINING or STORED chip under each.
- **Moods:** those training are livelier (a roar where the Kennel's would
  nap), and those stored nap more.

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
| The pen | `Client.DaycarePen` | Built on each player's screen, and mounted, shown and stepped by `OutpostScene` in the quarry's frame. The server keeps who's in it in `ReplicatedStorage.DaycarePen`, the boarded kaiju of the players in this server, at most 12 drawn. They wander like the Kennel's (`KaijuKennel.state` with `Daycare.Pen`). |
| The window | `Client.DaycareUI` | Boarding, the price shown up front, and collecting. |

## Next: offers

Next, other players will be able to make offers on boarded kaiju, through the
Market's offers and escrow, so nothing can be duplicated.

## Tests

`tests/run_daycare.py`
