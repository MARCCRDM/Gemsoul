# The lobby

The Outpost is where players land between fights. The lobby screen should
answer three questions at a glance:
- **what do I do next?**
- **what do I get for it?**
- **who else is here?**

![The lobby on a desktop](lobby/lobby-desktop.png)

## Left: play and your miner

- **PLAY** shows how many miners are online and how many are searching for
  a 1v1. When you're alone it lists the modes instead. A band of light
  sweeps across it now and then.
- **INVENTORY**, then MARKET, STORE, RANKS, SOCIAL and INVITE.
- **Your card**:
  - your level badge, name and coins;
  - the XP still needed for the next level ("40 / 150 XP to level 6").

## Right: the board

`src/client/Modules/LobbyBoard.luau`, under TASKS and REPORT A BUG:

| Card | What it shows |
| --- | --- |
| Daily streak | The week of rewards, today's day, and what tomorrow pays |
| Daily challenges | Today's three: progress bars, the coins each pays, the bonus for all three, and how long until new ones |
| Next unlock | Only while a mode is still locked behind duels |
| Next task | The next Tasks step with its hint and progress. Tapping it opens the Tasks window |

A challenge that finishes flashes gold on its row.

On a phone there is room for one card:
- the **next task** while a player is still learning (the first two Tasks
  pages: mining and gear);
- the **challenges** after that.

## Daily challenges

Each player gets three challenges a day, one from each group. They're new
every day at midnight UTC.

| Group | Challenges |
| --- | --- |
| Mining | Break 10 rocks (40 ◆) · Mine 4 gems (50) · Find a Rare gem (75) |
| Fighting | Beat 2 rivals (60) · Cast 8 Surges (45) · Guard 12 hits (40) · 3 perfect guards (50) |
| Gear | Socket 2 gems (40) · Ready a Surge (30) · Land 30 hits (35) |

- **The bonus.** Clearing all three pays 50 more coins. A full day is
  160 to 225 coins.
- **Stable picks.** The picks come from the player and the day, so a rejoin
  or another server shows the same three.
- **Server-side counting.** Progress counts the same server events as Tasks
  (`PlayerData.training`), so nothing a client says counts.
- **Payment.** Each challenge pays once, with a toast:
  "DAILY CHALLENGE: Break 10 rocks +40 coins".
- **Network.** Progress reaches the lobby at most once a second
  (`Remotes.Challenges`). A fight counts every hit, and a full profile sync
  per hit would be heavy. The board redraws only while the lobby is on
  screen, and catches up as it shows.

The rules are `src/shared/DailyChallenges.luau`. A challenge is one table
row, so adding, retiring or re-pricing one is a one-line change. A retired id
in a saved day is skipped.

## Top: OUTPOST LIVE

`src/client/Modules/LobbyFeed.luau` keeps a short feed at the top of the
screen. It shows:
- Rare-or-better gems as they're mined ("Kade found a **Legendary** Thermal
  gem"), and yours ("**You** found…");
- duel results;
- players joining.

It shows three lines at most, each gone after 7 seconds. It only fills while
the lobby is on screen.

## Welcome back

The first time the lobby shows in a session, a banner celebrates the daily
reward the server just paid. It shows:
- the streak and the coins;
- the week with today lit up;
- what tomorrow pays;
- a nudge towards today's challenges.

It closes on a tap or after 8 seconds. The server marks the reward on the
player (`DailyReward`, `DailyStreak`); it used to send a plain toast.

![Welcome back](lobby/welcome-back.png)

## The PLAY menu

Each card shows what a win pays:

| Mode | Win |
| --- | --- |
| Practice | +25 ◆ (`Matchmaking.RivalWinCoins`) |
| Casual | +15 ◆ |
| Ranked | +40 ◆ |

Casual and Ranked also show how many players are searching right now. That
is counted from their `DuelQueue` attribute, with no extra server traffic,
and it refreshes every 2 seconds while the menu is open.

![The PLAY menu](lobby/play-menu.png)

## Other miners: DUEL, SPAR, PARTY

Walk within 10 studs of another miner and one card appears beside them, at
chest height, with three buttons. Before, these were three of Roblox's own
prompt panels stacked over their head: hard to read, and on a phone they
covered the middle of the screen.

![The card on a desktop, on a phone, and in Spanish](lobby/player-card.png)

- **Click or tap** a button, or press its key: **G** to duel, **Z** to spar,
  **F** to invite to a party. A held key fills its button. A gamepad has a
  button for each (X, Y, B), so all three stay live together.
- **On a phone** the buttons are 44 points tall, and the keys aren't shown.
- It hides while a menu is open, during a fight, and when the lobby HUD is
  hidden.

The server still puts a prompt for each on the miner (`socialPrompts` in
`OutpostServer`). Their `Style` is Custom, so Roblox draws nothing. They decide
who's in range and take the keys. `PlayerCard` draws the card when they show,
and runs the same action as the key when a button is pressed.

## On a phone

![The lobby on a phone](lobby/lobby-phone.png)

- PLAY sits between two pills: level and coins on the left, who's online on
  the right.
- The bug button shortens to "🐞 BUG".
- The feed fits between the pick card and the buttons.

## Tests

| Suite | Checks | What it covers |
| --- | --- | --- |
| `tests/run_daily_challenges.py` | 22,446 rules + 8 server | One per group; stable rolls; progress; paying once; the bonus; new days; old saves. The server side: progress pushes, payouts, notes and the bonus |
| `tests/run_lobby.py` | 23 board + 16 feed | The real board and feed against GUI doubles. Board: cards per screen; the phone's choice; challenge rows; the bonus; the streak; unlock; no redraws while the lobby is hidden; opening Tasks. Feed: rare finds only; "You"; escaped names; three lines; duels; arrivals; a hidden lobby; the welcome once; Tasks stepping aside |
