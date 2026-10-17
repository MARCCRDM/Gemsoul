# Phones

A phone held on its side is about 844 x 390 points, and the menus were drawn
for 1366 x 768. Scaled down to fit, the Inventory showed at about a third of
its size and the windows at about half. On a phone they are now laid out
for the short screen, and they keep clear of Roblox's own buttons at the top.
The desktop layouts are unchanged (checked pixel for pixel against renders
of the previous version).

| Before | After |
| --- | --- |
| ![Inventory before](mobile/inventory-before.png) | ![Inventory after](mobile/inventory-after.png) |

## What counts as a phone

`UiKit.short()` is true when the screen is under 500 points tall: a phone on
its side. Before the camera knows the screen size, a touch screen without a
keyboard counts as one. Windows read it once, when they're built.

## The lobby and fights

The lobby and the fight screen are cleared down to what you use, like a
phone game should be.

![The lobby on a phone, before and after](mobile/lobby-phone.png)

- **Chat is Roblox's.** On a phone or tablet (a touch screen without a
  keyboard) our chat box and its CHAT button are gone. Roblox's own chat
  takes over: the speech-bubble button in the top bar, with its unread
  count, opens the recent lobby chat, and what people say pops up as a
  bubble over their head (bubble chat is on for everyone). A computer keeps
  the full chat box (`ChatFrame.Handheld`).
- **Level and coins** sit in a pill at the top left, under the pick card,
  where the CHAT button was (`MobileLayout.wallet`).
- **The "online" pill is gone.** PLAY stands alone at the bottom centre.
- **The six buttons under PLAY** are icons with their name small under
  them, 44 points tall.
- **Tasks:** the TASKS button, and under it the next task as one slim
  strip: its name and reward over a thin bar. Tap it to open Tasks. After
  the first Tasks pages, the strip shows the next daily challenge instead.
- **No BUG button** on a phone. The same form is SOCIAL's Feedback button.
- **The live feed** fits in the gap between the pick card and the task
  strip, so on a small phone they don't overlap.

![The lobby on a small phone, before and after](mobile/lobby-small-phone.png)

TASKS and REPORT A BUG looked greyed out (on every screen). Their buttons
are coloured by a gradient, and a gradient tints a button's own text too, so
their words came out nearly black. The words are now labels of their own.
(The offline renders don't draw that tint, so they show the old buttons
bright.)

### In a fight

![The fight buttons on a phone, before and after](mobile/fight-phone.png)

- **No HEAVY button.** Holding ATTACK already charges a heavy blow; ATTACK
  now swings each hand in turn, as a click does. The first fight's "HOLD
  ATTACK, release for a heavy" hint rings ATTACK.
- **The ring sits at the right edge**, under the right thumb: ATTACK in the
  corner, Q / E / R round it, GUARD and DODGE outside them.
- **No chat box** in a fight (Roblox's chat button is still in the top bar).

## The Inventory

When the full 1600 x 840 layout would show at under 70% of its size, the
Inventory is built compact instead (`chooseLayout` in `InventoryV2`), at
990 x 380:

- **No stats column.** The miner's column on the left keeps miner 1 / 2 / 3,
  the name, the 3D miner and the GEMS / SKINS buttons.
- **Equipment in two columns of three rows**, with the Q / E / R gem cards
  under them. A tapped piece opens in their place.
- **Larger text.** The small print (under 13 px on desktop) is drawn at
  13 px, and the wallet's captions shrink to fit rather than spill.
- **A tap opens a piece** (there's no hover tooltip on a touch screen).
- **The Gem Vault, the Wardrobe and the triad intro** are drawn for the full
  layout, so on a phone they open on a full-screen layer of their own,
  scaled as large as the screen allows.

The tabs along the top shrink together if their words run longer than the
row (Spanish does), so they never run into the coins.

![The Gem Vault on a phone](mobile/gems-phone.png)

## The windows

Each of these is shorter on a phone, so it scales up larger:

| Window | Desktop | Phone | What gives |
| --- | --- | --- | --- |
| Market | 900 x 640 | 900 x 520 | Smaller picture when inspecting; the Sell form drops its details box |
| Store | 1100 x 660 | 1100 x 520 | The product page is stacked tighter; the Free page scrolls; the bundle sheet is shorter |
| Season Path | 1000 x 560 | 1000 x 470 | The note under the track |
| Social | 1060 x 600 | 1060 x 470 | The party card is tighter; the Arena card's list scrolls |
| Surge Array | 1060 x 600 | 1060 x 520 | The gem pouch scrolls; the loadout card moves up beside it |

Every `IronUi.window` also uses nearly all the screen's height on a phone
(16 points spare, not 40).

![Market, Store, Season Path and Social on a phone](mobile/windows-phone.png)

### Roblox's buttons

The windows and the Inventory ignore the top bar's inset, so a window that
fills a phone's height reaches the top of the screen, under Roblox's menu
and chat buttons. `UiKit.clearTopbar(screen, size)` reads
`GuiService.TopbarInset` and either moves the window beside the buttons or
shrinks it to fit below them, whichever leaves it bigger. The Store, every
`IronUi.window`, the Store's offer pop-up and the Inventory's pop-up layer
use it. On a desktop screen it does nothing.

### Scale on a phone

How large each screen shows (1 = as drawn), before and after. The renders
assume Roblox's buttons end 188 points from the left.

| Screen | 844 x 390 | 667 x 375 |
| --- | --- | --- |
| Inventory | 0.36 → 0.82 | 0.34 → 0.64 |
| Gem Vault, Wardrobe | 0.36 → 0.46 | 0.34 → 0.43 |
| Market | 0.55 → 0.70 | 0.52 → 0.59 |
| Store | 0.57 → 0.62 | 0.55 → 0.58 |
| Season Path | 0.62 → 0.69 | 0.60 → 0.63 |
| Social | 0.58 → 0.69 | 0.56 → 0.59 |
| Surge Array | 0.58 → 0.62 | 0.56 → 0.59 |
| Augments | 0.50 → 0.53 | 0.48 → 0.44 |

The Augment tree keeps its size. On the smaller phone it gives a little to
get out from under Roblox's buttons, which it used to sit under.

## Helpers

| Helper | What it does |
| --- | --- |
| `UiKit.short()` | True on a phone on its side |
| `UiKit.clearTopbar(screen, size)` | Keeps a centred window clear of Roblox's buttons: returns a further scale and a Position |
| `UiKit.fit(label)` | Keeps a one-line label at its size, shrinking it only when its words don't fit |
| `UiKit.shrinkRow(row, list)` | Shrinks a row laid out side by side to its parent's width when its contents outgrow it |

## Also fixed

- The Starter Pack banner (desktop too): the price, the old price and the
  saving in one row were wider than the price box. The saving now sits in
  the box's corner.

## How the renders are made

As in [ui-style.md](ui-style.md): Lune runs the client modules against
stand-in Roblox services, writes the GUI tree as JSON, and a headless browser
draws it. 3D models and the world are placeholders. For a phone the
stand-ins give the screen at 844 x 390 (and 667 x 375), with Roblox's
buttons drawn as grey shapes at the top left.
