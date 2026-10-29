# The store (2026-10-15)

The store sells looks (never stats) and, since 2026-10-28, the Kennel's
kaiju (see [kaiju-kennel.md](kaiju-kennel.md)). It is built like a shop online:
categories along the top, product grids with a product page beside them, and
bundles that show what they hold and how much you save. Nothing random is
sold but the Starter Rare Roll, whose odds it shows. The lobby's button for it
says STORE (it said SKINS).

On a phone it's the whole screen, with the categories down a rail on the
left and the coins and close button in Roblox's strip at the top (see
[mobile.md](mobile.md#the-store-takes-the-whole-screen)).

Code:
- `src/shared/Store.luau`: the catalog, prices and the rules for who can buy what.
- `src/server/Systems/StoreServer.luau`: purchases and receipts.
- `src/client/Modules/ShopUI.luau`: the store screen.
- `src/client/Modules/CoinShop.luau`: the coin packs' window.

## Sections

| Tab | What's there |
| --- | --- |
| **Featured** | The front page: the new-player offer (while it's open), then the Kennel's two big kaiju deals side by side (the Starter Rare Roll and the Triskull Trinity), then the player bundles and the premium sets. |
| **Kaiju** | The Kennel's sales, big: the Starter Rare Roll first (R$ 150, once ever; every rare kind as likely as the next, odds shown; a Rare stone with the best E surge), then the Triskull Trinity (R$ 500, once ever; three Triskulls, Fire, Frost and Shock, each an Ultra Rare stone with the best Q, E and R; in its picture each stands over a glow of its element's colour with its element tagged at its feet, and the elements are named in their colours under the title), then the Kaiju of the Day (its kind, element, role, trait floor and the clock to the next one). A kaiju bought joins your reserves, or its roll plays on the roll screen, so the store closes for it. The team revive is no longer on this page, but it still works (`Store.RobuxProducts.KaijuRevive`, sold from the kaiju panel). |
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

## Coin packs (2026-10-28)

Coins are sold for Robux in a window of their own (`src/client/Modules/CoinShop.luau`),
apart from the Store and the Market, in the Kennel's gilt look. Four packs
side by side, each bigger one cheaper per coin:

| Pack | Robux | Coins a Robux | Saves |
| --- | --- | --- | --- |
| 10,000 coins | 1,000 | 10 | (the standard rate) |
| 25,000 coins | 2,250 | 11.1 | 10% |
| 50,000 coins (*Popular*) | 4,250 | 11.8 | 15% |
| 100,000 coins (*Best value*) | 7,500 | 13.3 | 25% |

Each card shows its pile of coins (bigger with the pack), the saving, and
what it would cost at the first pack's rate, struck through. The packs are
`Store.CoinPacks`; their products `Coins10k`, `Coins25k`, `Coins50k` and
`Coins100k` (ids 0 until they're made: the window still shows the prices,
and a click says they're coming). A pack can be bought any number of times;
its coins come with the receipt (`StoreServer.grantProduct`).

**Where it opens**

- **Your coins, anywhere.** Click (or tap) them on the lobby card, the
  phone's wallet pill, the Store's wallet (it has a gold **+** now), the
  Inventory's COINS and the Market's total (`CoinShop.hook`).
- **Short of coins.** A request the server turns down for want of coins says
  how many more it takes (`Shop.short`: a reply's `CoinsShort`), and the
  window opens by itself (`GemClient.onCoinsShort`). It says "You need ◆ N
  more for that." and marks the smallest pack that covers it (*Covers it*,
  `Store.coinPackFor`). So far: a Market buy, a kaiju battle stake (set or
  matched), a Rift RESTORE, and anything test-bought for coins. On the
  Market, a listing you can't afford says **GET COINS** instead of NOT
  ENOUGH COINS, and opens it.

## Bundles

Every bundle costs less than its looks bought one by one. The store shows
this honestly:

- The struck-through price is the sum of the looks that are sold on their own.
- Bundle extras (trims, back pieces, titles) are listed as extras and not counted in that sum.
- A look you already own still comes in the bundle, as 120 coins instead, and the bundle's page says so before you buy.

| Bundle | For | Robux | Inside | Saves |
| --- | --- | --- | --- | --- |
| Welcome Kit | new players, once, within 24 h of joining | 49 | Camo suit + skin, War Banner, 1 h 2x XP | 75% |
| Starter Pack | once, for 48 h after your first win | 99 | Ignition suit (only here), Molten Core, Bone Crusher, Thermal Core visor (*2026-10-28*: was Ember Trim), 1,000 coins | 68% + exclusive |
| Royal Treasury | large | 1,499 | Royal Gold, Chrome Knight, Stealth Black, Galaxy, Stormbreaker, Prism Shard, Gilded Prospector, Ember Cape, 5,000 coins, 24 h 2x XP | 24% |
| The Vault | largest, once per account | 4,999 | Every weapon skin, suit, helmet, visor and pickaxe in the store (63), every bundle extra, the COLLECTOR title, 10,000 coins, 24 h 2x XP | 53% |

### Player bundles (2026-10-28)

Each player bundle is one whole look for your miner: a suit, a weapon skin, a
helmet, a visor and a pickaxe (one of each), most with a trim or back piece
too. Buying one puts the whole look on.

| Bundle | Robux | Suit | Weapon skin | Helmet | Visor | Pickaxe | Extra | Saves |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Scrapyard Hauler | 199 | Rust Rig | Rust Bucket | Hard Hat | Hi-Vis Lime | Bone Crusher | Prospector's Pack | 43% |
| Copper Shogun | 349 | Copper Coil | Copper Wire | Shogun Kabuto | Gold Mirror | Gilded Prospector | War Banner | 44% |
| Toxic Prospector | 399 | Biohazard | Toxic Ooze | Deep Diver | Toxic Bloom | Amethyst Geode | Venom Trim | 47% |
| Glacier Juggernaut | 449 | Arctic Ops | Glacier Shard | Jarl's Horns | Cryo Frost | Glacier Fang | Glacier Trim | 44% |
| Reaper's Harvest | 449 | Stealth Black | Void Crystal | Grim Reaper | Twilight | Void Reaper | | 45% |
| Storm Caller | 499 | Storm Conductor | Plasma Edge | Mech Ace | Ion Storm | Stormbreaker | Storm Trim | 46% |
| Neon Rush | 499 | Neon Runner | Circuit Board | Shark Bite | Spectrum | Neon Runner | | 46% |
| Deep Space Explorer | 549 | Nebula Suit | Nebula | Star Bubble | Aurora | Prism Shard | | 46% |
| Solar Warlord | 799 | Obsidian Lava | Solar Flare | Wyrmking | Supernova | Magma Heart | Ember Cape | 48% |

**No longer sold.** The squad kits (one look per miner, from when every
player had three) and the five launch collections (Rustbucket, Brainrot,
Circuit & Copper, Deep Space, Solar Forge) are off the store. They stay in
`Store.luau` with `Section = "Retired"` (the kits in `Store.Kits`):
`Store.retired` says so, `Store.canBuy` refuses them, and a purchase of one
still going through is granted. Their Developer Products can be taken off
sale on Roblox. The FULL SQUAD title stays with whoever bought it.

## Buying

The flow:

- **Buy** opens Roblox's own purchase prompt, and an order confirmation follows ("Thank you!").
- Every bundle opens a page listing each piece, what it costs on its own, the totals and the saving.
- **What goes on:**
  - A look you buy is worn at once.
  - A bundle puts its look on the miner you're playing (its first suit, skin, helmet, visor and pickaxe).
  - The Vault leaves your looks as they are.
- **What can't be bought** (`Store.canBuy`, used by both the buttons and the server):
  - a one-time offer that's closed or already bought;
  - a bundle no longer sold (`Store.retired`);
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
   - for PROBE-7's swing refills, their own `Robux` in `Outpost.Refills`
     (`SwingRefill` R$ 100 for 600 swings, `SwingMega` R$ 225 for 2,000).
2. Paste each product's id into `Store.RobuxProducts`.
   - Or let `tools/create_dev_products.py` do it: it creates every product
     whose id is 0 (by name, at its price) and writes the ids in.
   - **The nine player bundles are new: their ids are 0 until that's done.**
3. Until a product's id is set, its button says "Coming soon" (or buys for coins while testing).

Purchases are safe to retry:

- Each purchase is granted once, by its `PurchaseId`.
- The profile is saved straight away, and the purchase counts as done only
  once that save has gone through.
- A session that doesn't save (its save didn't load, or another server took
  it) grants nothing: the purchase waits for one that does.

## Tests

`tests/skins_store_cases.luau` (2,494 checks) covers:

- **The catalog:**
  - every look can be had: sold, earned, a bundle extra or on the Season Path;
  - nothing is sold for coins and no look names a crate.
- **Bundles:**
  - every bundle holds real looks, sells no gems or crates, and costs less than its looks one by one;
  - The Vault holds every look sold on its own.
- **Player bundles:** one suit, weapon skin, helmet, visor and pickaxe each, a product slot, a name no other product has, at least 40% off, and the whole look put on.
- **Retired bundles and kits:** never buyable or suggested, still granted when a purchase goes through.
- **Who can buy what:** the Welcome Kit's 24 hours, the Starter Pack's window, The Vault once, things you own.
- **Receipts:** once each, every product type, and owned looks refunded as coins.
- **Old crates:** refunded at cost, once.
- **Test purchases for coins.**
