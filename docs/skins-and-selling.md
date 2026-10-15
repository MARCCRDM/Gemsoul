# Skins and selling (2026-10-13)

Cosmetics are looks only, never stats. Some are sold for Robux, directly
(never at random). Others are free, earned one way only, so wearing one shows
how you got it.

The store itself, with its bundles, squad kits and prices, is in
`docs/store.md` (2026-10-15). It replaced the crates and the coin-priced trims
and back pieces described in older notes.

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
| Starter Pack | Ignition suit (only here), Molten Core, Bone Crusher, Ember Trim, 1,000 coins | 99, one time, for 48 h after your first win |
| Season premium | a second reward track: Moonsteel skin, LUNAR VANGUARD title, Lunar Frontier suit, coins | 399 |

Every skin, suit and pickaxe for sale, and the bundles, are listed in
`docs/store.md`.

### Free (exclusive, never sold)

| Do this | Get this | Where it's handled |
| --- | --- | --- |
| Bring 1 friend | **Kindred Edge** (Legendary weapon skin, only from here) | `Systems/Referrals` |
| Bring 2 friends | Twin Star (pickaxe) | `Systems/Referrals` |
| Bring 3 friends | Crusader's Standard (back piece) | `Systems/Referrals` |
| Bring 4 friends | Crusader Gold (weapon skin) | `Systems/Referrals` |
| Bring 5 friends | Crusader Plate (suit) | `Systems/Referrals` |
| Bring 10 friends | CRUSADER LEGEND (title) | `Systems/Referrals` |
| Join the Roblox group | Starforged (weapon skin) | `Systems/FreeRewards` |
| Log in 7 days in a row | Daybreak (weapon skin) | `PlayerData` (the daily streak) |
| Redeem a promo code | whatever the code gives (LAUNCH: the FOUNDER title) | `Systems/Codes` |

Free rewards are put on as soon as they're earned, so other players see them.
The Shop's **Free** tab shows every one, with your progress.

### Bring a friend

**Kindred Edge** is the first reward (`SKINS.Kindred` in `Equipment.luau`), a blade "forged for two":

- A dark, starlit crystal blade.
- Two strands of neon, teal and gold (the gold matches the hilt), wind round each other from the guard to the point. They're built from short linked neon parts, so they show in shop previews and in first person too.
- The edge pulses with white starlight.
- Teal and gold motes drift up off the blade, and its swing trail runs from teal to gold.

How a friend counts (`Systems/Referrals`):

1. You invite them with Roblox's game invite, from the lobby's **INVITE** tile or the Shop's Free tab. Both run `ReferralUI.invite`. In a Studio playtest it says invites only work in the live game.
2. When they join, Roblox tells the server who invited them (`ReferredByPlayerId`), and that friend is counted once, in a DataStore. A failed save is tried 3 times.
3. If you're in the same server, the reward goes on at once.
4. If you're in another server, a MessagingService message (`GemsoulReferralJoined`) carries your new count there, and it goes on at once.
5. If you're offline, it goes on at your next join, or when you press **CHECK CLAIM**.

The Bring a Friend window shows the skin turning in 3D. Once it's yours, the progress row moves on to the next reward, and the second button puts the skin on or takes it off.

## The designs (the full collection)

There are 27 weapon skins and 21 suits, all of them in `src/shared/Cosmetics.luau`. Renders of every
one:

- `docs/skin-designs/skins_gallery.png`
- `docs/skin-designs/suits_gallery.png`

A palette can ask for more than one colour:

| Palette field | What it draws |
| --- | --- |
| `Accent` + `Pattern` | A second plate colour. **Camo** is patches, the same on both sides. **Stripes** is bands across the body. **Trim** is the smaller plates: edges, straps, veins. |
| `Seams` | Plates outlined in neon: the 12 biggest of each armor piece, or the 6 biggest of a weapon. |
| `Blade` + `BladeMaterial` (skins) | The blade's own colour and material: lava for Molten Core, glass for Glacier Shard, neon for Solar Flare. |
| `Edge` (skins) | The blade outlined in neon, a little thicker than the seams. |
| `SeamColor` | The outline's colour. Without it, outlines take the glow colour. Bonk Bat and Banana Blade also use it for their neon bands. |
| `SeamWidth` | The outline's thickness, from 0.018 (Frontier) to 0.036 (Solar Flare). Rarer looks get bolder lines. |
| `SeamFx` | Makes the outlines move (see below). Without it they stay steady. |

### How a suit paints armour

A suit recolours the armour you wear (`repaint` in `Equipment.luau`, with `suit` set), but keeps it looking like armour:

- **The visor stays as it is.** The builders mark visor parts (the glass, the dark well behind it, a bucket helm's slits) with a `Visor` attribute (`ArmorKits.visorPart`). The repaint skips them, so every suit keeps your armour's own visor colour.
- **Light and shade are kept.** Each part takes the palette's colour at its own relative brightness, so a lighter edge stays lighter and a deep trim deeper, and the armour's detail still reads.
- **Nothing blacks out.**
  - A part keeps at least 85% of its own brightness under the plates, and 55% on them.
  - There's also a floor for each.
  - Dark suits (Stealth Black, Neon Runner, Obsidian Lava) read as gunmetal and indigo with their plates showing, not as a black silhouette.
- **Clean finishes only.**
  - Suits use SmoothPlastic, Metal, Foil, Glass or Neon. Gritty textures (fabric weave, rust, concrete, slate, basalt, marble) are gone.
  - Weapon skins drop the gritty ones too. They keep the materials that make them: Molten Core's lava blade, Glacier Shard's ice, Bonk Bat's wood.
  - `tests/skins_store_cases.luau` checks this for every look.

### The neon look

Every suit and every weapon skin has glowing outlines, like Neon Runner and Raid
Breaker always had:

- Every suit has `Seams`.
- Every palette skin has an `Edge`.
- All but the three cheapest (Frontier Steel, Rust Bucket, Camo Ops) also outline the guard and grip with `Seams`.
- Bonk Bat and Banana Blade have neon bands instead.

The tests check this for every look.

Each look has its own colour pairing: plate, under, and a contrasting outline. Pale looks get strong outlines so the lines still show:

- gold on Champion Plate;
- violet on Lunar Frontier;
- gold to red on Crusader Plate.

Steady outlines are the default. `SeamFx` animates them on every client (`SeamVisibility`). 21 looks use it:

| SeamFx | What it does | Looks |
| --- | --- | --- |
| `Pulse` | Breathes, bright to dim and back (1.8 s). | Circuit Rig, Obsidian Lava, Neon Runner, Lunar Frontier, Champion Plate; Molten Core, Circuit Board, Champion's Edge, Ore Vein Gold |
| `Shift` | Swings between the outline colour and the glow (2.6 s). | Royal Gold (gold to amethyst), Nebula Suit, Crusader Plate (gold to red); Daybreak, Void Crystal, Nebula, Crusader Gold |
| `Flicker` | Crackles like a live wire, with sharp flashes of the glow. | Storm Conductor, Raid Breaker; Warlord's Edge, Solar Flare |
| `Rainbow` | Runs through every hue. | Chrome Knight; Galaxy |

How the effect gets to the client:

- The server only tags each outline (`Equipment.outline`): `SeamFx`, `SeamA` (its own colour) and `SeamB` (the glow).
- `SeamVisibility` reads those attributes once per box and again only when a restyle changes them.
- It recolours just the animated boxes that are showing.
- A box restyled to a steady look goes back to its own colour.
- Shop and Wardrobe previews show the outlines as neon bars (a SelectionBox doesn't draw in a ViewportFrame), in their base colour.

Three skins have their own look in `Equipment.luau`:

- **Solar Flare** (`SKINS.Solar`): the palette plus flames along the whole blade.
- **Bonk Bat** and **Banana Blade** (`SKINS.Bonk`, `SKINS.Banana`): they swap the weapon's model for
  their own, built along the old blade and held the same way.

Where the new ones come from:

| Source | Items | Works now? |
| --- | --- | --- |
| Everyone | Frontier Steel, Frontier Fatigues | Yes: given to every profile on load. |
| Store (once crates) | Rust Bucket 49, Rust Rig 99, Camo Ops skin 49 and suit 149, Copper Wire 79, Copper Coil 149, Circuit Board 99, Circuit Rig 249, Nebula 199, Nebula Suit 399 | Once their Developer Products exist. Crates are gone; these are sold directly and in bundles. |
| Robux | Glacier Shard 99, Bonk Bat 149, Banana Blade 149, Stealth Black 199, Storm Conductor 299, Biohazard 299, Solar Flare 399 | Once their Developer Products exist (the slots are in `Store.RobuxProducts`). |
| Season 1 free track | Crater Grey (level 15), Moon Dust (level 25) | Yes |
| Achievement, Ranked, Raid, Mining | Veteran Steel, Champion's Edge, Champion Plate, Warlord's Edge, Raid Breaker, Geode Crust, Fossil Bone, Fossil Shell, Ore Vein Gold | Not yet. They're in the Shop with how to earn them (`How`), but the systems that grant them are still to build. |

## To switch selling on

Nothing sells for Robux until you create its product.

1. On the game's page on Roblox: **Monetization > Developer Products**. Create
   one product per row of the Robux table above, at its price.
2. Paste each product's id into `Store.RobuxProducts` in
   `src/shared/Store.luau`. The key is the cosmetic's id (`SkinPlasma`,
   `SuitRoyal`, …), or `StarterPack` or `SeasonPremium`.
3. Until an id is set, pressing Buy says it's coming soon (or, while
   `Config.TestCosmeticPrice` is set, buys it for coins). Bundles and squad
   kits need products too: see `docs/store.md`.

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
  - CRUSADERS: 500 coins
  - GEMRUSH: 750 coins + 30 min of 2x XP

## Roblox rules to keep to

- **Discord:** don't reward joining a Discord server, or any other off-Roblox
  action. Roblox doesn't allow it, and the game can't check it anyway. Post
  codes in Discord instead, since anyone can redeem them. Discord links belong
  on the game page's Social Links, which Roblox shows only to users old
  enough to see them.
- **No random items for sale.** The store sells only named looks and bundles;
  crates are gone. Keep it that way: paid random items need odds shown and
  are restricted in some countries.
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
