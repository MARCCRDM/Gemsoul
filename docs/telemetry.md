# Telemetry: the game's own analytics

The game keeps its own event log in a DataStore you own (`SagaTelemetry_v1`),
alongside what goes to Roblox's Creator Dashboard. `tools/telemetry` pulls it
out with Open Cloud and builds a dashboard you open in a browser.

## What's recorded (Server/Systems/Telemetry.luau)

Every row: time, UserId, event, a number, up to three fields.

| Event | Number | Fields |
|---|---|---|
| `session_start` | account age (days) | new / returning, country |
| `session_end` | seconds played | level, coins, ping (ms) |
| `device` | 1 | phone / tablet / desktop / console, screen size, locale |
| `onboarding` | funnel step | step name (Server.Funnel) |
| `store_funnel` | Store funnel step | step name |
| `coins` | +in / −out | reason (Duel, Store, Market...), kind |
| `Purchase` | Robux spent | product, "Robux" |
| `IntroRound` | round | slot, rarity or Lost, Won / Done / Lost |
| `DuelFinished` and every other custom event the game sends Roblox | as sent | as sent |
| `server` | players in the server (every 5 minutes) | place version |

Each server saves its own rows under `ev/<UTC day>/<hour>/<server>` every 5
minutes and when it shuts down. Studio writes to `SagaTelemetry_Studio`
instead, so tests never mix with real data.

## Setup (once)

1. **Get the universe ID:** Creator Dashboard > your experience > the "..."
   menu > Copy Universe ID.
2. **Make an API key:** Creator Dashboard > Open Cloud > API Keys > Create.
   Add the **DataStore** API system, choose this experience, and tick
   **List entry keys** (`universe-datastores.objects:list`) and **Read entry**
   (`universe-datastores.objects:read`). Nothing else. Restrict it to your IP
   if you like. Keep it out of the repo: it only ever goes in an environment
   variable.

## Every time you want fresh numbers

```
export ROBLOX_OPEN_CLOUD_KEY=...      # the key from step 2
export ROBLOX_UNIVERSE_ID=...         # from step 1
python3 tools/telemetry/pull.py 14    # the last 14 days (keys already pulled are skipped)
python3 tools/telemetry/report.py     # -> tools/telemetry/dashboard.html (+ dashboard.json)
```

Open `tools/telemetry/dashboard.html`. It works offline, light or dark, on a
phone too. The pulled data and the dashboard are git-ignored.

## The dashboard

- **Tiles:** players today (and the 7-day average), new players, day-1 and
  day-7 retention, average session, revenue and payers (7 days), revenue per
  daily player, peak players online.
- **Players per day** (daily and new), **onboarding funnel** with the drop at
  each step, **intro rounds** (won and lost per round), **retention cohorts**
  (day 1, 3, 7 by first day), **session lengths**, **revenue** per day and by
  product, **coins** in by source and out by sink, **duels** by mode and result,
  **devices**, **countries**, **peak players online**, and the **25 most
  frequent events**.

`python3 tools/telemetry/test_report.py demo.html` checks the numbers on a
known log and writes a DEMO dashboard from made-up data (clearly marked).
Tests: `python3 tests/run_telemetry.py`.
