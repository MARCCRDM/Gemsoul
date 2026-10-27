# The store (2026-10-15)

The store sells looks only, never stats. It is built like a shop online:
categories along the top, product grids with a product page beside them, and
bundles that show what they hold and how much you save. Nothing random is
sold.

On a phone it's the whole screen, with the categories down a rail on the
left and the coins and close button in Roblox's strip at the top (see
[mobile.md](mobile.md#the-store-takes-the-whole-screen)).

Code:
- `src/shared/Store.luau`: the catalog, prices and the rules for who can buy what.
- `src/server/Systems/StoreServer.luau`: purchases and receipts.
- `src/client/Modules/ShopUI.luau`: the store screen.

## Sections

| Tab | What's there |
| --- | --- |
| **Bundles** | The new-player offer (while it's open), the squad kits, the collections and the premium sets. |
| **Weapon Skins**, **Suits**, **Helmets**, **Visors**, **Pickaxes** | A grid of every look, sorted by featured or by price, showing all of them or only the ones you don't own. Beside it is the picked look's page: a 3D preview, the price, buy (or wear), and the bundle that saves on it. Looks earned in play show after the ones for sale, each saying how to earn it. |
| **Free** | The group, friends, the 7-day login streak and promo codes. |

What was removed or moved:

- **Featured, Back Pieces, Trims and Passes are gone.**
  - Trims and back pieces are now bundle extras and Season Path rewards.
  - Trims, back pieces and titles are worn from the **Wardrobe**, which has new TRIMS, BACKS and TITLES tabs.
  - Season premium is bought on the Season Path screen.
- **Crates are gone.**
  - The looks that only came from crates are now sold on their own.
  - Crates left in a save are refunded as coins at what they cost (Geode 250, Masterwork 800), once, on load.
  - Season Path and promo-code crate rewards are now coins.

## Bundles

Every bundle costs less than its looks bought one by one. The store shows
this honestly:

- The struck-through price is the sum of the looks that are sold on their own.
- Bundle extras (trims, back pieces, titles) are listed as extras and not counted in that sum.
- A look you already own still comes in the bundle, as 120 coins instead, and the bundle's page says so before you buy.

| Bundle | For | Robux | Inside | Saves |
| --- | --- | --- | --- | --- |
| Welcome Kit | new players, once, within 24 h of joining | 49 | Camo suit + skin, War Banner, 1 h 2x XP | 75% |
| Starter Pack | once, for 48 h after your first win | 99 | Ignition suit (only here), Molten Core, Bone Crusher, Ember Trim, 1,000 coins | 44% + exclusive |
| Rustbucket Set | small | 99 | Rust Rig, Rust Bucket, Prospector's Pack | 33% |
| Brainrot Duo | small | 199 | Banana Blade, Bonk Bat | 33% |
| Circuit & Copper | medium | 349 | Circuit Rig + Board, Copper Coil + Wire | 39% |
| Deep Space Set | medium | 599 | Nebula suit + skin, Void Crystal, Void Reaper | 36% |
| Solar Forge Set | medium | 699 | Obsidian Lava, Solar Flare, Magma Heart | 29% |
| Royal Treasury | large | 1,499 | Royal Gold, Chrome Knight, Stealth Black, Galaxy, Stormbreaker, Prism Shard, Gilded Prospector, Ember Cape, 5,000 coins, 24 h 2x XP | 24% |
| The Vault | largest, once per account | 4,999 | Every weapon skin, suit, helmet, visor and pickaxe in the store (63), every bundle extra, the COLLECTOR title, 10,000 coins, 24 h 2x XP | 53% |

### Squad kits (one, two or all three miners)

Each kit is one look per fighting style: a suit, a weapon skin, a pickaxe and
a trim. In the squad builder you tick the kits you want, and the price follows
the ladder.

| Kit | Suit | Skin | Pickaxe | Trim |
| --- | --- | --- | --- | --- |
| Toxic Prospector | Biohazard | Toxic Ooze | Amethyst Geode | Venom |
| Storm Skirmisher | Storm Conductor | Plasma Edge | Neon Runner | Storm |
| Glacier Juggernaut | Arctic Ops | Glacier Shard | Glacier Fang | Glacier |

| Kits | Robux | Saves |
| --- | --- | --- |
| 1 | 349 | 29–36% |
| 2 | 599 | 39–42% |
| 3 (Squad Bundle) | 799 | 48%, plus the FULL SQUAD title, which only comes with all three |

**Each kit dresses one miner.** The first kit goes on the miner you're
playing, the next on the following miner, and so on. You can change any of it
in the Wardrobe.

## Buying

The flow:

- **Buy** opens Roblox's own purchase prompt, and an order confirmation follows ("Thank you!").
- Every bundle opens a page listing each piece, what it costs on its own, the totals and the saving.
- **What goes on:**
  - A look you buy is worn at once.
  - A bundle puts its first suit, skin and pickaxe on the miner you're playing.
  - The Vault leaves your looks as they are.
- **What can't be bought** (`Store.canBuy`, used by both the buttons and the server):
  - a one-time offer that's closed or already bought;
  - a product whose every look you already own.

### While testing

While `Config.TestCosmeticPrice` is set (25 now), anything for sale can be
bought for that many coins. It uses the same grant as a Robux purchase (the
`BuyProduct` request), and the product page says so. **Set it to nil before
launch.**

## To switch Robux on

Nothing sells for Robux until its Developer Product exists.

1. On the game's page on Roblox, go to **Monetization > Developer Products**.
   Create one product per key in `Store.RobuxProducts`, at the price shown:
   - a look's own `Robux` (in `Cosmetics.luau`);
   - otherwise `Store.RobuxPrices`;
   - for kits, `Store.KitPrices` (1 kit 349, 2 kits 599, 3 kits 799).
   - for PROBE-7's swing refills, their own `Robux` in `Outpost.Refills`
     (`SwingRefill` R$ 49 for 600 swings, `SwingMega` R$ 129 for 2,000).
2. Paste each product's id into `Store.RobuxProducts`.
   - The squad kits need seven products, one per choice: `KitProspector`, `KitSkirmisher`, `KitJuggernaut`, `KitProspectorSkirmisher`, `KitProspectorJuggernaut`, `KitSkirmisherJuggernaut` and `KitProspectorSkirmisherJuggernaut`.
3. Until a product's id is set, its button says "Coming soon" (or buys for coins while testing).

Purchases are safe to retry:

- Each purchase is granted once, by its `PurchaseId`.
- The profile is saved straight away.

## Tests

`tests/skins_store_cases.luau` (2,494 checks) covers:

- **The catalog:**
  - every look can be had: sold, earned, a bundle extra or on the Season Path;
  - nothing is sold for coins and no look names a crate.
- **Bundles:**
  - every bundle holds real looks, sells no gems or crates, and costs less than its looks one by one;
  - The Vault holds every look sold on its own.
- **Kits:** all seven choices have a product and the ladder's price; all three add the squad title; the kits dress the right miners.
- **Who can buy what:** the Welcome Kit's 24 hours, the Starter Pack's window, The Vault once, things you own.
- **Receipts:** once each, every product type, and owned looks refunded as coins.
- **Old crates:** refunded at cost, once.
- **Test purchases for coins.**
