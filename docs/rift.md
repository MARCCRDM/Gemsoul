# The Rift: through a Rift Vein's gate into the critters' world

Each of the three Rift Veins in the quarry now has a **Rift Gate** over its
dormant tear: a jagged arch of slate with fire at its feet, where the
violet beam used to be. Walk up to one and you can go through, into the
critters' own world: a burning path of islands over a sea of lava, under a
blood moon. You fight your way across with your kaiju, island by island,
then face one of the ten brainrot bosses, picked at random, on its throne.

It's built for a party. You can go in alone, but the game warns you first.

![The Rift: the landing, a pack on island 2, a causeway, the throne island](rift/world.jpg)

The pictures are offline renders of the parts the server builds
(`Server/World/RiftWorld`, `Server/World/OutpostWorld.veinMarks`), drawn by
the trailer renderer. The actors are the game's own models posed at the
game's scales. They are **not Roblox screenshots**. Fire in the game is
Roblox `Fire` particles; the renders stand in a few glowing flame strips
for it. The UI shots are the real client code rendered by the UI harness.

## The gate

![A Rift Gate on the moon](rift/gate.jpg)

- **On the moon** (`OutpostWorld.veinMarks`): a scorched bed with glowing
  cracks, a 13-shard arch with neon inner edges and fire at its feet, and
  the vein's tear hanging in it, drawn in the Hell palette (`RiftTear`).
  The guarded vein's cracks are in its own red. The old `VeinBeam` is gone.
- **Its prompt**: **Enter the Rift** (`ProximityPrompt` on the gate's
  `Heart`, `PromptKind` "Rift", attribute `Vein` = the vein's index).
- **The card** (`RiftClient`), before you go in:

![The gate's card, alone](rift/gate-card.png)

  - what's through it (the islands, the boss, robbery if you fall);
  - when you're alone, a warning box with the warning sign: **GOING ALONE
    IS VERY DIFFICULT**. "Invite a friend, or bring your party: up to 4
    can go in together." Then **INVITE A FRIEND** (the invite window) and
    **ENTER ALONE**;
  - with a party, how many of you there are and **ENTER**; if your party is
    already in there on the path, you join them;
  - **Not now**.

  On phones it's a compact two-column card:

  ![The gate's card on a phone](rift/gate-card-phone.png)

- **Crossing**: the screen goes dark red for a moment with **THE RIFT**
  (and the warning again if you're alone), then the lighting turns hellish
  (`RiftClient.Hell`). Coming home puts the Outpost's lighting back.

## A trip

The rules are `Shared.RiftRun`; the server is `Server.RiftServer`.

| | |
| --- | --- |
| **Islands** | 4, one after another, joined by sloped causeways with bone arches |
| **Critters** | 3, 4, 5, 6 on islands 1 to 4, plus 1.5 for each runner past the first (rounded). Brainrot critters from the Outpost's roster; a ranged one only at the back |
| **Big ones** | From island 2, a 60% chance that one of the pack is a **Rift Brute**: 4x health, 1.5x damage, longer reach |
| **Level** | Your team's level (the average of the runners' lead kaiju), +2 on island 1, +1 more per island; the boss +3 over the last island. Capped at 30 |
| **Walls of fire** | Each island's way on is barred by a wall of fire until its pack is down |
| **Caches** | Clear an island and everyone in finds a gem (`RiftCache`, "Found in the Rift"), 12% luckier on island 1 and 6% more each island |
| **The boss** | One of the ten brainrot bosses at random, 1.7x size, 40x health (+60% per extra runner), 2.6x damage. It tears through when the first runner reaches the throne island. At 66% and 33% health it calls 3 critters through |
| **Boss moves** | Each boss has its own: Twin Pounce, Firebomb Dive, Quack Squall, Bog Leap, Banana Smash, Triple Bat Slam, Twin Shark Dash, Spore Storm, Freezer Blast, Knife Flurry |
| **Beaten** | Everyone still in: 300 coins + 40 per island cleared, a lucky cache, 120 EXP for their kaiju, and swings back on their pick (the dungeon restore). The way home opens; 25 seconds later everyone is home |
| **The lava** | Fall off the path (30 studs under it) and you're thrown back onto the last island you reached, 15% of your health gone |

Your kaiju come with you: you keep the Outpost's attribute, so
`KaijuServer` keeps them out and follows you, jumping when you jump. The
Outpost's own critters, stranded check and lobby healing leave you alone
while you're in the Rift (`RiftRun` attribute).

### The HUD

A strip at the top (claims the top slot like the other top bars): pips for
the islands and the throne, where you are, what's left, gems found and how
many are in.

![The Rift strip](rift/strip.png)

## Going down

Down in the Rift works like down in the Outpost: a critter's blow knocks
you down (`SparDown`), it doesn't kill you.

- **On the path**: the critters rob you. Half the gems you've found in
  there (at least one), the newest first, are taken out of your pouch, and
  you're thrown back to base. "You went down. The critters robbed you: 2
  of the gems you found in the Rift, gone."
- **At the boss**: you stay down and choose.

![Down at the boss](rift/down.png)

  - **RESTORE · 150 COINS**: you and your kaiju, every one of them, back to
    full health right there (`KaijuServer.restoreAll`). It doubles each
    time in a trip (150, 300, 600...). Coins only, no Robux;
  - **INVITE A FRIEND**: the invite window, while you wait;
  - **BACK TO BASE**: home with the gems you found;
  - nothing chosen in 60 seconds: back to base.

  Your kaiju fight on without you while you're down.

## Together

- Up to 4 in a trip. Party members can join through **any** gate while the
  trip is still on the path (not once it's at the boss).
- The pack sizes and the boss's health grow with each runner.
- While you're in the Rift, nothing else can start for you: spars, kaiju
  battles, duels and the duel queue, raids and the dungeon queue, the
  Arena and expeditions all answer "Leave the Rift first." or "Sam is in
  the Rift." (It would pull you out mid-trip.)

## Leaving

- **The way you came in**: the landing's opening (prompt **Go home**),
  keeping what you found.
- **The way home** on the throne island opens once the boss is down.
- Leaving the game ends your trip.

## Where it lives

| File | What |
| --- | --- |
| `src/shared/RiftRun.luau` | The rules: packs, levels, the boss, caches, rewards, robbery, RESTORE's price |
| `src/server/World/RiftWorld.luau` | Builds a trip's world far off in the dark: basalt islands with glowing cracks, horns and braziers, sloped causeways with bone arches, walls of fire, the throne island, the lava sea, black spires, the blood moon, ash |
| `src/server/Systems/RiftServer.luau` | Runs trips: `RiftEnter`, `RiftLeave`, `RiftChoice`, `RiftPeek` |
| `src/client/Modules/RiftClient.luau` | The gate's card, the crossing, hell lighting, the strip, the down window |
| `src/server/World/OutpostWorld.luau` | The gate on each vein (`veinMarks`) |
| `src/client/Modules/RiftTear.luau` | The tear in the gate, in the Hell palette |
| `src/server/Systems/KaijuWilds.luau` | `spawnBug` options for the Rift's packs and boss (`Spec`, `Scale`, `Health`, `Damage`, `Reach`, `Title`, `Stay`, `Boss`) |
| `src/server/Systems/Duelist.luau` | A boss's body is its own (`BrainrotBosses.apply`) |

A runner carries `RiftRun`, `RiftRoom`, `RiftLeft`, `RiftBoss`,
`RiftFound`, `RiftRunners`, `RiftWon`, `RiftExitAt`, and when down at the
boss `RiftFallen` and `RiftRestore`.

## Spanish

Every line above is in `Shared.LangEs`: the card, the warning, the strip,
the down window, the server's messages and the prompts. Boss and move
names stay in English (they're names).

## Tests

| Suite | What it checks |
| --- | --- |
| `run_rift` | 12,656 checks: pack sizes and levels, the elite, every boss picked over many draws and each with its moves, adds, caches, rewards, robbery, RESTORE's price, the solo warning. The world: islands spaced and reachable, causeways sloped rim to rim with no step, walls of fire that open, the ways home, the lava under everything, parts per trip (626). And nothing else starts for a runner |
| `run_kaiju` (`kaiju_server_cases`) | A whole trip on the server: going in, packs, a wall opening, caches, robbery on the path, down at the boss, RESTORE, BACK TO BASE, joining a party, winning and going home |
| `run_outpost` | Each vein has its gate, prompt, arch, glow, cracks in its colour and its index |
| `run_topbar` | The crossing is a cover; the card, strip and down window keep clear of Roblox's buttons |
