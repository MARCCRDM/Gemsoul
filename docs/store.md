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
| **Bundles** | The new-player offer (while it's open), the player bundles and the premium sets. |
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
