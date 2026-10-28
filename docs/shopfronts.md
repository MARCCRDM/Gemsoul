# The Store and the Market: lit shopfronts

2026-10-27. The two shopfronts on the Shelter's west wall were plain grey
alcoves with an off-white lightbox. Each is now lit in its own colour, so
you can tell them apart from across the hall (`OutpostWorld`'s
`storefront`, `SHOP`).

The renders below are offline stand-ins built from the game's own parts and
sign GUIs, not Roblox screenshots. The Store's stands (suits, helmets,
skins, picks) are drawn by each client (`Client.StoreDisplays`) and aren't
in them.

![West wall, before and now](shopfronts/both.jpg)

## Both

- **The lightbox** is lit in the shop's colour (the Store cobalt, the
  Market green) with its one word in white. It throws that colour onto the
  front (a SurfaceLight). It still says only STORE or MARKET (the
  [plain signs](plain-signs.md) rule).
- **The columns** are dark, with a strip of the shop's colour lit down each
  face.
- **The counter** has a lit line along its foot and under its steel top.
- **A mat** in the shop's colour lies on the floor in front.
- **A canopy** slopes out over the counter from under the sign.

## The Store

![The Store, before and now](shopfronts/store.jpg)

- A plain cobalt canopy with a warm strip lit along under its lip.
- Its back wall (the client's display wall) is deep blue, framed in the
  Store's lit blue, and the helmets' shelf is lit along its edge.

## The Market

![The Market, before and now](shopfronts/market.jpg)

- A stall's canopy: green and cream stripes with a pennant under each.
- Nothing on the counter's front but its two lit strips: the board of
  green and red candles that was on it is gone (*2026-10-27*).
- Two strings of warm bulbs under its ceiling, front to back.
- Three crates of gear by its south corner, near Tamsin, banded in the
  Market's green.

## The makeover (2026-10-28)

![Both, before and now](shopfronts/makeover-both.jpg)

![The Store, before and now](shopfronts/makeover-store.jpg)

![The Market, before and now](shopfronts/makeover-market.jpg)

These renders do include the Store's stands. Their things are grey
stand-ins (the test's previews); in the game each is the Shop's own
dressed preview.

- **A marquee of warm bulbs** round each lightbox, 15 along the top and
  bottom and three down each side.
- **Two blade signs** per shop, standing out from the fascia at each end
  on a bracket, the shop's word on both faces in its colour, each with
  its own light. You can read which is which walking along the wall.
- **The mat** has lit edges in the shop's colour, and the column strips
  are twice as wide.
- **More on show** (`Client.StoreDisplays`): the back wall is four
  helmets, four weapon skins and four picks wide (was three), and six
  suits turn instead of two, four round the Store and two in front of the
  Market. 18 cosmetics on show, up from 11, all still the Shop's own and
  changing on the turn.

Tested in `tests/signage_cases.luau`:

- both lightboxes are lit in a colour of their own, with a white word;
- no candle board (`PriceBoard`) on the Market's counter;
- STORE and MARKET each on five signs: the lightbox and both faces of
  its two blade signs.

And in `tests/store_displays_cases.luau`: four of each on the wall, six
suits, the Market's two kept to the Market and clear of Tamsin and Borin.
