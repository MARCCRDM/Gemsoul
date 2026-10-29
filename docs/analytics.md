# Analytics

What the game sends to the Creator Dashboard (Analytics). Two server
modules send it:
- `src/server/Systems/Funnel.luau`: the onboarding funnel, a new player's
  first session (see [beta-launch.md](beta-launch.md#onboarding-funnel)).
- `src/server/Systems/Analytics.luau`: everything below, which is coins,
  events and the Store funnel.

Every send is fire-and-forget. A send that fails prints one warning and
never stops the game.

## Coins (Economy)

Every change to a player's coins carries a reason. The changes are added up
per player and reason, then sent once a minute, when the player leaves and
when the server shuts down. That keeps a busy server inside Roblox's event
budget.

Each send is one Economy event per reason. Coins in are a Source and coins
out are a Sink. Every event carries the balance the player ends on.

A change that nobody tagged still counts, as **Other**. Analytics compares
the real balance with what it has counted, so the dashboard's totals always
match the players' balances.

| Reason | Type | What |
| --- | --- | --- |
| Duel | Gameplay | A 1v1 / 2v2 result |
| QueueBonus | Gameplay | Stepping in to fill a queue |
| Rival | Gameplay | Beating the sparring rival |
| Raid | Gameplay | A party raid wave |
| Streak | Gameplay | An Arena win streak milestone |
| Dungeon | Gameplay | A dungeon clear |
| Rift | Gameplay | A Rift run |
| Enemy | Gameplay | An enemy beaten |
| Critters | Gameplay | Critters your kaiju beat |
| Secret | Gameplay | An Outpost easter egg |
| MineWall | Gameplay | Coins dug out of the Moon Mine wall |
| KaijuBet | Gameplay | A kaiju battle stake, paid or won |
| Season | Gameplay | A Season Path level's reward |
| GemSale | Shop | Gems sold for coins |
| DailyLogin | TimedReward | The daily login reward |
| DailyChallenge | TimedReward | A daily challenge (and the all-three bonus) |
| Tasks | Onboarding | A task in the Tasks window |
| Tutorial | Onboarding | The tutorial's coins and its first buy |
| Code | Onboarding | A redeemed code |
| Store | Shop | Bought with coins in the Store, and its refunds |
| MineEntry | Shop | A Moon Mine wall past the free ones |
| Market | Shop | Market board buys, sales, refunds and commissions |
| RiftRestore | ContextualPurchase | A Rift RESTORE paid in coins |
| CoinPack | IAP | A coin pack bought with Robux |
| Bundle | IAP | Coins in a Robux bundle, or for a cosmetic you already had |
| Legacy | Gameplay | Old saves' materials, turned into coins |
| Other | Gameplay | Anything untagged |

**In code.**
- `PlayerData.addCoins(player, n, reason)` and
  `PlayerData.spendCoins(player, n, reason)` take the reason.
- Code that writes `profile.Coins` directly calls
  `Analytics.coins(player, delta, reason)` after the change.
- A new reason goes in `Analytics.Reasons`, with one of Roblox's transaction
  types.

## Events (Custom)

| Event | Value | Fields (1, 2, 3) |
| --- | --- | --- |
| KaijuCaught | Tries it took | Species, element |
| DuelFinished | 1 | Mode (Intro, Ranked, Casual...), Win/Loss/Draw, team size (1v1, 2v2) |
| BossDefeated | Players in the party | Boss id, Dungeon/Rift, the Rift's element |
| Hyperbeam | Kaiju in the blast | Targets, Boss/Foes |
| PlayerLevel | The level reached | |
| PurchasePrompt | 1 | Product, Bought/Closed |
| Purchase | 1 | Product (a granted Robux receipt) |
| CoinPurchase | Price | Product bought with coins in the Store |

## The Store funnel (Funnels)

This is a recurring funnel, named **Store**. Each visit is its own session:
1. **Opened store.** The client reports it when the Store window opens. A
   visit lasts 15 minutes; closing and reopening the Store within 30
   seconds stays in the same visit.
2. **Viewed an item.** The client reports it once per visit, when a product
   is picked or a buy button is pressed.
3. **Saw a price prompt.** Roblox's purchase prompt closed, bought or not.
4. **Bought.** A Robux receipt was granted.

Only steps 1 and 2 come from the client, through the `Funnel` remote, and
only by name. Steps 3 and 4 come from the server. A step counts only while
a visit is open, so a purchase made elsewhere in the game doesn't count
toward the Store funnel. It still logs its Purchase event.

## Where it's wired

| Where | What |
| --- | --- |
| `Main.server.luau` | `Analytics.start(Remotes.Funnel, Store.productKey)` |
| `PlayerData` | Tracks the balance on load; tags daily login, challenge and task coins; flushes on leave |
| `StoreServer` | Tags coin packs, bundles, refunds and Season coins; logs purchases |
| `MarketBoard`, `Intro`, `FreeRewards` | Tag their direct coin changes |
| `KaijuWilds`, `Duels`, `Dungeons`, `RiftServer`, `KaijuBeamServer`, `Progress` | The custom events |
| `ShopUI` (client) | Reports Opened store and Viewed an item |

## Tests

`tests/run_analytics.py` runs 157 checks:
- coins are batched per reason, and untagged changes count as Other;
- refunds cancel out, and bad input is ignored;
- the sent totals equal the balance over 200 random changes;
- leaving and shutting down flush what's left, and a failing send warns once;
- custom event fields are sent;
- the Store funnel: step order, one session per visit, reopening, expiry,
  purchases without a prompt, and bad client input.
