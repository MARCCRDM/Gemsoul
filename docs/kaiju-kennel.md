# The Kaiju Kennel

The stage in the middle of the Shelter's hall used to carry a hologram of
a kaiju. It's the **Kaiju Kennel** now: a fenced pen where the rarest kinds
of kaiju wander about, with **Wren**, the kennel keeper, at the gate.

## The hologram

Switched off, not deleted: `ShelterLife.Hologram = false`
(`src/client/Modules/ShelterLife.luau`). With it off the hologram, its
name plate and its projector console are taken out of the world and never
posed. Set it to `true` to bring it back somewhere else.

## The pen (`src/client/Modules/KennelLife.luau`)

The server builds only the stage and its bed of packed earth
(`OutpostWorld`, `KennelBed`): the Shelter's server-built parts were at their
budget (`tests/run_moon_quarry_scene.py`, under 4000). The rest is built by
each player's own client, next to today's kaiju, and shown and hidden with
them: a rock to climb in the middle, troughs by the fence, a fence of 28
posts with two rails between each pair (solid to your own character, so
players stay outside), and a **KENNEL** arch over the gate. The gate, the
sale's display in front of it and Wren all face the garage: players come
into the hall through the barrier from there, so they're the first things
you see. One word, like the hall's other signs.

## The Daily Kaiju Sale

In front of the gate (`Kennel.Display`) the Kaiju of the Day
(`Kennel.special`) turns slowly on a plinth, its board beside it: DAILY
KAIJU SALE, its kind, element and role, and the price. The plinth's prompt,
or Wren's **Daily Kaiju Sale** option, opens the sale window
(`src/client/Modules/KennelSale.luau`), in the Bounty Board's gilt look
(`src/client/Modules/GiltUi.luau`). It has three offers, shown in this
order:

- **Starter Rare Roll** (`KaijuRareRoll`, **R$ 150**): once per miner
  (`profile.KaijuRareRollBought`). One roll on the starter roll's screen
  from the rarest batch only (`Kaiju.rareKinds`), with traits of 6 or
  better. Its Gemsoul is a **Rare** stone, made to order with its element's
  best E surge (`Kaiju.BestMoves`, `Kaiju.Sale.Rare.Best = "Ability"`).
  It's owed as `profile.KaijuRareRolls` and plays like a boss roll, as soon
  as you have room (`Kaiju.rareRollsOwed`, counted in `bossRollsOwed`). Its
  card shows four of the rarest kinds turning (`Kaiju.Sale.Showcase`:
  Emberjaw, Razorclaw, Dreadcrown and Brightsteel), in a 2x2 grid.
- **Triskull Trinity** (`KaijuPremium`, **R$ 500**): once per miner
  (`profile.KaijuPremiumBought`). Three Triskulls, the three-headed dragon,
  one Fire, one Frost and one Shock (`Kaiju.Sale.Premium`), with traits of 8
  or better. Each Gemsoul is an **Ultra Rare** stone with its element's best
  Q, E and R surges (`Best = "All"`). They join your reserves, even past a
  full roster. Its card is gold edged and shows the three turning.
- **Daily Kaiju Sale** (`KaijuDaily`, **R$ 200**): today's kaiju, one each a
  day (`profile.KaijuDailyDay`). It comes with traits of 8 or better in all
  four and a luckier Gemsoul (`Kaiju.Sale.Daily`). It joins your reserves,
  even past a full roster. Paid for twice in one day, the second becomes a
  rare roll, so nothing is lost.

**No roll's cards deal a support kind** (the starter roll, the rare roll,
boss rolls, the Kaiju of the Day): `Kaiju.rareKinds`, the starters and
`Kennel.special` leave the support kinds out. The one support anyone is
given is the starter Skyjelly (below); the rest are caught.

Both are Roblox developer products (`Store.RobuxProducts`). Their ids are
0 until the products are made: listed by `tools/dev_products_manifest.luau`,
then pasted in. Until then, the window says they're coming soon (or takes
coins while testing). A receipt is granted by `StoreServer.grantProduct`
through `KaijuServer.saleGrant`.

## Who lives there (`src/shared/KaijuKennel.luau`)

- **Residents**: six kinds a day, all from the rarest batch (the first 30
  kinds after the starters, `Kaiju.batch == 1`), each in an element of its
  own. They change at midnight, server time.
- **Kaiju of the Day**: one more kind of that batch a day, never one of
  the residents. It stands on its own display in front of the gate (see
  the Kaiju of the Day).
- **What they do**: each resident has a wedge of the pen to itself, so two
  never walk into each other. Every few seconds it either walks to a new
  spot in its wedge (turning to face the way first) or stays put and
  sniffs the ground, looks about, lies down, sleeps or roars.

All of it comes from the day and the server's clock, so every player sees
the same kaiju doing the same thing at the same moment, and the server
sends nothing. `Kennel.state(index, count, now)` gives a resident's spot,
facing, speed and mood at any moment.

## Drawing them (`src/client/Modules/KennelLife.luau`)

Each client builds today's residents from `KaijuModels` (at 0.75 scale),
with nothing on them that can be touched, clicked or hit, and moves them
30 times a second while you're near the Shelter. `CreatureAnimation` poses
them like any kaiju: their legs walk at the speed the kennel says
(`PacedSpeed`), since they're moved rather than pushed, and their moods are
the wild kaiju's (`KaijuMood`).

## Wren (`Vendors.KaijuKeeper`)

By the gate, facing the door:

- **Daily Kaiju Sale** opens the sale window.
- **Buy and sell kaiju** opens the Market on kaiju.
- **Kaiju and their kinds**: why these are rare, how to get one, what the
  Daily Kaiju Sale is, and who's in the pen today.
- **Give me a tip**: kennel and kaiju tips.

## The starter support

On again since 2026-10-29 (`Kaiju.StarterSupport.On = true`). Every new
account gets a Skyjelly with the intro's roll, automatically: its only roll
is its element, any of the four, evenly (`Kaiju.supportElement`), and the
roll card shows it under the three starter kinds. Accounts made while it
was off (2026-10-28 to 29) get theirs, any element, on their next visit to
the Outpost (`Kaiju.supportOwed`); a starter roll left unclaimed from then
gets one added when it's shown. Any support kind you
own (a Warden) can take the support slot (SET AS SUPPORT in the kaiju
panel, or drag it onto the slot), and swap with the one there.

## Tests

`tests/run_kaiju_kennel.py`: residents and the Kaiju of the Day by day
(rarest batch, no overlap, changing daily, cycling through the batch),
every resident inside its wedge and the pen, no jumps or spins, every mood
seen, no two ever touching, and every client working out the same. Also
the pen (the client's) and its bed (the server's), Wren and her options,
the hologram off, the animation hooks, the sale's rules and Store entries
(R$ 200, R$ 500 and R$ 200; once ever, once ever, once a day), the made to
order stones (Rare with the best E; Ultra Rare with the best Q, E and R),
no support kind in any roll's cards, every support kind in the slot, and
the starter support's element. `tests/run_kaiju.py` (kaiju_server_cases)
grants all three sales and plays the rare roll.
