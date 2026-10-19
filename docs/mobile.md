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
  bubble over their head (bubble chat is on for everyone). A computer gets
  the windowless chat feed in the bottom left (`ChatFeed`; see
  [lobby.md](lobby.md#chat-the-bottom-left-windowless)). The old chat box is
  off for now.
- **Level and coins** sit in a pill at the top left, under the pick card,
  where the CHAT button was (`MobileLayout.wallet`).
- **The "online" pill is gone.** PLAY stands alone at the bottom centre.
- **The six buttons under PLAY** are icons with their name small under
  them, 44 points tall.
- **Tasks:** a small TASKS button (112 x 34), and right under it the next
  task as one slim strip: its name and reward over a thin bar. Tap it to
  open Tasks. After the first Tasks pages, the strip shows the next daily
  challenge instead.
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

### Mining in the Outpost

![Mining on a phone, before and after](mobile/mining-phone.png)

Mining with your kaiju out covered the middle of the screen. The loot card
sat over PLAY with its last find on top, and every creature's name and
health bar showed at full size from far off. Now the middle is left to
you, your kaiju and what's coming:

- **The loot card** is slim and sits at the top middle, between the pick
  card and TASKS (`MobileLayout.loot`). It shows the reel, the rarity and
  element, and the gem's name with its worth, but no stat bars. The last
  find sits as one row under it. The live feed steps aside while the card
  is up (`MobileLayout.claimTop`) and comes back when it goes. See
  [mining-loot.md](mining-loot.md#phones-and-spanish).
- **PLAY** is narrower and shorter (184 x 38), and so is the dock under
  it, so it takes up less of the bottom of the screen.
- **TASKS and the task strip** are smaller and tucked into the top right
  (`MobileLayout.tasks`, `MobileLayout.board`).
- **Names over heads** (`Nameplates`, every few frames from `KaijuHud`):
  - your own kaiju have no name (the team strip has them), and their bar
    shows only while one is hurt;
  - another player's kaiju show theirs from 30 studs;
  - wild kaiju show theirs from 60 studs, and critters from 45;
  - wild kaiju and critters show nothing while you hunt, since the fight's
    own bars take over.

  The names are smaller too. A computer keeps the longer distances (70,
  160 and 90), but there too your own kaiju go unnamed, and their bar shows
  only while hurt.

On a small phone the card is shorter, so it ends above the task strip. Its
row waits until the card has gone, then shows in its place. Each find is
still in chat, and a full pouch still gets its message.

![Mining on a small phone](mobile/mining-small-phone.png)

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
| Store | 1100 x 660 | 860 x 340 | Its own layout: tabs in a slim header, a three-column grid beside a compact product page, narrower squad kits, a shorter bundle sheet |
| Season Path | 1000 x 560 | 760 x 440 | A shorter XP bar; the note under the track |
| Social | 1060 x 600 | 860 x 340 | Its own layout: one section at a time (Miners, Party, Arena, Friends, Chat) under tabs in the header |
| Surge Array | 1060 x 600 | 1060 x 520 | The gem pouch scrolls; the loadout card moves up beside it |

Every `IronUi.window` also uses nearly all the screen's height on a phone
(16 points spare, not 40).

![Market, Store, Season Path and Social on a phone](mobile/windows-phone.png)

### Roblox's buttons

Roblox draws its own buttons in a strip along the top of the screen: the
Roblox button, then a pill with its menu, chat and voice, on the left. On a
phone the strip is 58 points tall, and its buttons reach about 265 points in
from the screen's left edge on a notched phone (about 205 on one without a
notch). A tap there goes to Roblox, never to us, so nothing of ours may sit
under them.

A screen that leaves the strip alone (a `ScreenGui`'s default) starts below
it. The windows, the Inventory and a few overlays draw over it
(`IgnoreGuiInset`), and those keep themselves clear of the buttons:

| Helper | What it does |
| --- | --- |
| `UiKit.topbar(width)` | The strip's height, where Roblox's buttons end, and where its free part ends on the right (less the DEV button's room) |
| `UiKit.clearTopbar(screen, size)` | A centred box that would reach under the buttons moves beside them or shrinks to fit below them, whichever leaves it bigger. A box already clear stays as it is |
| `UiKit.onTopbar(fn)` | Calls `fn` when the strip changes: Roblox draws its buttons, opens or closes its menu, or the DEV button comes. Returns a function that stops it |
| `UiKit.reserveTopbar(width)` | Keeps the strip's right end for our own button (DEV) |

**Why the Wardrobe sat under them.** Roblox fills in
`GuiService.TopbarInset` a moment after our screens are built. Until then it
reads empty, so a screen laid out at once (the Inventory's pop-ups, the
Wardrobe and the Gem Vault among them, and the Store) placed itself as if
there were no buttons, and never looked again. The Wardrobe's title and
first tab sat under Roblox's buttons, and its ✕ under the DEV button. Now:
- an empty reading assumes the usual strip (58 tall, buttons to 290);
- every screen laid out around the strip lays itself out again when Roblox
  fills it in (`UiKit.onTopbar`);
- it applies on every screen size, not only phones. On a desktop or tablet a
  window that reaches the top is moved down a little.

**What uses it:**
- every `IronUi.window`, the Store and its offer pop-ups;
- the Inventory and its pop-ups (Gem Vault, Wardrobe);
- the dashboard (its top margin is the strip's real height, not a fixed 54);
- the 1v1 panel between rounds;
- the mine's top bar (just below the strip where it would reach the buttons);
- the tutorial's card and SKIP (just below the strip);
- the loading guide preview.

**The DEV button** (testers, touch screens) sits at the strip's right end,
centred on it, and keeps that end (`UiKit.reserveTopbar`). A window that
reaches into the strip stops short of it, so it can't cover a close button.

**Tests.** `tests/run_topbar.py`:
- checks the rules on six screens (phones, a tablet, a desktop) with seven
  window sizes: before and after Roblox draws its buttons, with DEV, and
  with Roblox's menu opened wide;
- checks that every screen drawn over the strip uses these helpers or is a
  listed full-screen cover with nothing in the strip: the loading screen, the
  title screen, the drop pod's flash, damage numbers and the spar flash.

**Renders.** 24 phone renders were drawn with Roblox's buttons and the DEV
button in place: at 844 x 390, at a notched phone's 726 x 390 safe area and
at 667 x 375, each both as the buttons appear and after.

- **Before:** with the strip still empty, 10 screens (13 renders) had
  something of ours under Roblox's buttons or DEV: the Wardrobe, the Gem
  Vault, every Store tab, the Starter offer, the Season Path, Social, the
  Market, the Surge Array, the Augment tree and the mine's top bar. On most
  of them the ✕ sat under DEV.
- **After:** no button or text is under either, on any of them. What is
  left in the strip is backdrop: the intro's dark band and the title
  screen's art.

![Before and after: the Wardrobe, the Store, Social and the mine's HUD on a phone](mobile/topbar-before-after.png)

### Scale on a phone

How large each screen shows (1 = as drawn), before and after. These renders
assumed Roblox's buttons end 188 points from the left; they reach about 265,
so the windows that reach the top now shrink a little more to sit below
them (see Roblox's buttons, above).

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
| `UiKit.topbar(width)`, `UiKit.onTopbar(fn)`, `UiKit.reserveTopbar(width)` | The strip Roblox's buttons sit in, a call when it changes, and room in it for DEV (see [Roblox's buttons](#roblox-s-buttons)) |
| `UiKit.fit(label)` | Keeps a one-line label at its size, shrinking it only when its words don't fit |
| `UiKit.shrinkRow(row, list)` | Shrinks a row laid out side by side to its parent's width when its contents outgrow it |
| `MobileLayout.loot(screen)`, `tasks(screen)`, `board(screen)` | Where the slim loot card, TASKS and the task strip go on a phone |
| `MobileLayout.claimTop(owner, on)`, `topClaimed()`, `onTop(fn)` | Who has the top middle (the loot card), so the feed can step aside |
| `Nameplates.rule(kind, phone, hurt, shown)`, `Nameplates.apply(board, rule)` | When and from how far a creature's name and bar show |

## Also fixed

- The Starter Pack banner (desktop too): the price, the old price and the
  saving in one row were wider than the price box. The saving now sits in
  the box's corner.

## How the renders are made

As in [ui-style.md](ui-style.md): Lune runs the client modules against
stand-in Roblox services, writes the GUI tree as JSON, and a headless browser
draws it. 3D models and the world are placeholders. For a phone the
stand-ins give the screen at 844 x 390 (and 667 x 375).

Roblox's buttons are drawn at their real size and place: the Roblox button
and the menu pill, 44 points tall, to about 262 points across on 844 x 390.
The DEV button is drawn at its place too. Each screen the windows draw over
the strip is given its full height; the others start below the strip.
The renderer lists any button, text or box of ours under either one. Each
screen is drawn twice: as Roblox's buttons appear (`TopbarInset` empty) and
after.
