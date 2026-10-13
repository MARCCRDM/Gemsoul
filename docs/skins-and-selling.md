# Skins and selling (2026-10-13)

Cosmetics are looks only, never stats. Some are sold for Robux, directly
(never at random). Others are free, earned one way only, so wearing one shows
how you got it.

## What there is

| Kind | What it does | Where it's drawn |
| --- | --- | --- |
| Weapon skin | Restyles whatever weapon you hold: colours, material, sparks, a trail through every swing | `Equipment.luau`, `SKINS.Palette` |
| Suit | Restyles every armor piece, whatever its style: plates, under-layer, glow, particles off the chest | `Equipment.luau`, the suit pass in `dress` |
| Title | A tag over your head, in its colour, that everyone sees | `Equipment.showTitle` |
| Back piece / trim | As before. New: the Crusader's Standard back piece | `BACKS.Standard` |

Each skin and suit is a palette in `src/shared/Cosmetics.luau`, so a new one
is only a few lines of data.

### For Robux

| Item | Kind | Robux |
| --- | --- | --- |
| Plasma Edge | weapon skin | 99 |
| Molten Core | weapon skin | 99 |
| Toxic Ooze | weapon skin | 99 |
| Void Crystal | weapon skin | 149 |
| Galaxy | weapon skin | 199 |
| Chrome Knight | suit | 299 |
| Arctic Ops | suit | 299 |
| Obsidian Lava | suit | 399 |
| Neon Runner | suit | 399 |
| Royal Gold | suit | 799 |
| Starter Pack | Ignition suit (only here), Molten Core, Ember Trim, 3 Geode Crates, 1,000 coins | 99, one time, for 48 h after your first win |
| Season premium | a second reward track: Moonsteel skin, LUNAR VANGUARD title, Lunar Frontier suit, crates, coins | 399 |

### Free (exclusive, never sold)

| Do this | Get this | Where it's handled |
| --- | --- | --- |
| Bring 1 friend | Crusader Gold (weapon skin) | `Systems/Referrals` |
| Bring 3 friends | Crusader's Standard (back piece) | `Systems/Referrals` |
| Bring 5 friends | Crusader Plate (suit) | `Systems/Referrals` |
| Bring 10 friends | CRUSADER LEGEND (title) | `Systems/Referrals` |
| Join the Roblox group | Starforged (weapon skin) | `Systems/FreeRewards` |
| Log in 7 days in a row | Daybreak (weapon skin) | `PlayerData` (the daily streak) |
| Redeem a promo code | whatever the code gives (LAUNCH: the FOUNDER title) | `Systems/Codes` |

Free rewards are put on as soon as they're earned, so other players see them.
The Shop's **Free** tab shows every one, with your progress.

## To switch selling on

Nothing sells for Robux until you create its product.

1. On the game's page on Roblox: **Monetization > Developer Products**. Create
   one product per row of the Robux table above, at its price.
2. Paste each product's id into `Store.RobuxProducts` in
   `src/shared/Store.luau`. The key is the cosmetic's id (`SkinPlasma`,
   `SuitRoyal`, …), or `StarterPack` or `SeasonPremium`.
3. Until an id is set, the Shop shows that price greyed out ("R$ 99 · SOON"),
   and pressing it says it isn't on sale yet.

Purchases are safe to retry:

- Each Roblox purchase is granted once, by its `PurchaseId`. The last 200 are
  kept on the profile.
- The profile is saved right after a purchase.
- A bought skin or suit goes straight on.

## To switch the group reward on

Put your group's id in `Config.GroupId` (`src/shared/Config.luau`).

- **While it's 0:** the Free tab says "Coming soon".
- **Once it's set:** members get the skin on joining the game, and anyone who
  joins later presses CHECK.

## Promo codes

Codes live in `src/server/Systems/Codes.luau`. That file is server-only, so
players can't read the list out of the game.

- **To add one:** add a line with the code in capitals, its reward, and
  optionally an expiry date.
- **Redeeming:** each player can redeem each code once. Players can type it
  any way ("launch" or "Launch!" both work), and the server allows one try
  every 2 seconds, so codes can't be guessed by brute force.
- **The starter codes are examples.** Change them before posting:
  - LAUNCH: the FOUNDER title + 500 coins
  - CRUSADERS: 2 Geode Crates
  - GEMRUSH: 750 coins + 30 min of 2x XP

## Roblox rules to keep to

- **Discord:** don't reward joining a Discord server, or any other off-Roblox
  action. Roblox doesn't allow it, and the game can't check it anyway. Post
  codes in Discord instead, since anyone can redeem them. Discord links belong
  on the game page's Social Links, which Roblox shows only to users old
  enough to see them.
- **No Robux for random items.** Crates are bought with earned coins only, and
  `Store.luau` says so. Keep it that way: paid random items need odds shown
  and are restricted in some countries.
- **Joining the group and inviting friends** are both Roblox features. The
  game checks them with `IsInGroup` and the invite's join data. Both are fine
  to reward.

## Tests

`tests/skins_store_cases.luau` (`tests/run_skins_store.py`) covers:

- **The catalog:** every skin and suit can be drawn, every Robux item has a
  product slot, and exclusives are never sold.
- **Receipts:** every product type, each purchase granted only once, and
  unknown products refused.
- **Season premium:** claiming it once, and every premium reward.
- **The Starter Pack's 48-hour window.**
- **Promo codes:** each code once, codes typed loosely, made-up and expired
  codes, the 2-second limit between tries.
- **The group reward:** stays off with no id set.

`tests/referrals_cases.luau` covers the invite tiers.
