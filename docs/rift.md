# The Rift: through a Rift Vein's gate into the critters' world

Each of the three Rift Veins in the quarry has a **Rift Gate** over its
dormant tear: a jagged arch of slate with fire at its feet. Walk up to one
and you can go through, into the critters' own world: a walled pathway of
caves open to a burning sky. You go in with your combat kit out and your
kaiju beside you, fight your way through cave by cave against brainrot
critters and the pathway dungeon's fighters that lead them, every one of
them tearing through the floor at you, then face the boss you picked
at the gate, as a Colossus on its throne.

It's built for a party. You can go in alone, but the game warns you first.

![The Rift: a cave's pack, the throne cave, a passage with its wall of fire, the way from above](rift/world.jpg)

The pictures are offline renders of the parts the server builds
(`Server/World/RiftWorld`, `Server/World/OutpostWorld.veinMarks`), drawn by
the trailer renderer. The actors are the game's own models posed at the
game's scales. They are **not Roblox screenshots**. Fire in the game is
Roblox `Fire` particles; the renders stand in a few glowing flame strips
for it, and the sky's ash and lighting are only roughly matched. The UI
shots are the real client code rendered by the UI harness.

## The gate

![A Rift Gate on the moon](rift/gate.jpg)

- **On the moon** (`OutpostWorld.veinMarks`): a scorched bed with glowing
  cracks, a 13-shard arch with neon inner edges and fire at its feet, and
  the vein's tear hanging in it, drawn in the Hell palette (`RiftTear`).
  The guarded vein's cracks are in its own red.
- **Its prompt**: **Enter the Rift** (`ProximityPrompt` on the gate's
  `Heart`, `PromptKind` "Rift", attribute `Vein` = the vein's index).
- **The lobby** (`RiftClient.openGate`), before you go in. It is the
  gate's own lobby: who's going with you, who else is about, and the boss.

![The gate's lobby, on your own: three miners about, one at the gate](rift/gate-lobby.png)

  - **The header**: which Rift it is, the gate's biome and its element
    (**RIMEFROST · CRYO RIFT**), in the element's colour, and what's
    through it. **Not now** sits by the title.
  - **YOUR PARTY · n/4**: four places. Each member has their face (their
    Roblox headshot), their name, where they are (**AT THE GATE**, **IN
    THE OUTPOST**, **IN THE RIFT**, **NOT IN THE OUTPOST**, or **AWAY**
    when they're not in this server), **READY** or **NOT READY**, and
    **LEADER** on the leader. You're first and marked **YOU**. An empty
    place says **OPEN** · "Invite from the list". On your own you're the
    only member, ready, and no one is marked leader.
  - **CHOOSE YOUR BOSS**: the biome's ladder as a row of cards (see
    [The ladders](#the-ladders)). Each card has:
    - the boss's portrait: its real body, built once by the server into
      `ReplicatedStorage.RiftPortraits`, shown in a `ViewportFrame` from
      the front quarter;
    - its threat as pips (green, amber, red);
    - its **level** (`LV 13`) and its name;
    - its favourite gear, and how often you've beaten it.

    A locked boss is a dark silhouette marked **LOCKED**, with "Beat
    Tralalero Tralala to unlock". The card opens on the first boss you
    haven't beaten (`RiftRun.nextBoss`). **The leader picks**: in someone
    else's party, clicking a card says "Your party's leader picks the
    boss."
  - **Who's about**, on the right, in two tabs:
    - **IN THE OUTPOST n**: every other miner in the Outpost. Those
      within 30 studs of this gate come first (**At the gate**, in green),
      then your friends, then the rest by name. Each row has their face,
      name, level, where they are and **FRIEND** on a friend.
    - **FRIENDS n**: your Roblox friends online
      (`Player:GetFriendsOnline`, through `Client.SocialUI.friends`).
      Those here come first, then those playing in another server of
      this game (**Playing, another server**), then the rest
      (**Online**).
    - What a row offers: **INVITE** asks a miner here into your party
      (`PartyInvite`; leaders only, while there's room). **INVITE ↗** is
      Roblox's invite to the game, for a friend who isn't here. After a
      click the row says **INVITED** for a while. A miner already in a
      party says **IN A PARTY**, one in the Rift **IN THE RIFT**.
    - **INVITE FRIENDS TO THE GAME** under the list opens Roblox's invite
      window.
  - **The buttons**, by where you stand:

    | You are | The button | What it does |
    | --- | --- | --- |
    | On your own | **ENTER ALONE** | In you go |
    | Leading a party | **ENTER TOGETHER**, or **ENTER · 2 OF 3 READY** while some aren't | In you go, and everyone ready comes with you, wherever they are in the Outpost |
    | In someone's party | **READY** / **NOT READY** and **GO IN NOW** | Tell your leader you're set, or go ahead (they can follow) |
    | Your party's in there already | **JOIN THEM** | Through to wherever they've got to, against their boss (no ladder then) |

    A line under the buttons says the same in a sentence.
  - **Alone against a boss built for 2 to 4** (threat III), a warning box
    with the warning sign: **BRING FRIENDS**. "Frigo Camelo is built for
    2 to 4 of you. You can go in alone, but it won't be easy: invite
    someone from the list." You can still go.
  - **It keeps itself up to date** while it's open: your party
    (`SocialUI.PartyChanged`), your friends (`SocialUI.FriendsChanged`),
    miners joining and leaving, and once a second who's where. It only
    redraws when something changed. It closes by itself when you're taken
    in.

  ![Leading a party of three: Ivy at the gate and ready, Bram in the Outpost and not](rift/gate-lobby-party.png)

  ![In Ivy's party: READY and GO IN NOW, no INVITE (only the leader invites)](rift/gate-lobby-member.png)

  ![The FRIENDS tab: Kadey here, Sasha and Theo online elsewhere (INVITE ↗)](rift/gate-lobby-friends.png)

  ![Alone, picking the top of the ladder: BRING FRIENDS](rift/gate-lobby-warning.png)

  ![Your party's already in there: JOIN THEM](rift/gate-lobby-join.png)

  On phones the about line and the hint go, the party's places, the
  boss cards and the list are shorter, and the list scrolls:

  ![The lobby on a phone](rift/gate-lobby-phone.png)

  The pure part (who goes in which place, the rows, their order and what
  each offers) is `Shared.RiftLobby.lobby`, tested in `run_rift`.

- **Crossing**: the screen goes dark red for a moment with **THE RIFT**
  (and the warning again if you're alone), then the lighting turns hellish
  (`RiftClient.Hell`: a low red evening, thick red haze, no stars). Coming
  home puts the Outpost's lighting back.

**Brutus's bounty board** in the Shelter is the same lobby with a tab per
biome: every gate's ladder from one counter. See
[hall-of-fame.md](hall-of-fame.md#brutuss-bounty-booth).

## The ladders

Each biome's gate opens on a Rift of its element, and each Rift has its
own bosses, in order (`RiftRun.Ladders`). The first is built to beat
alone; the last (threat III) is built for 2 to 4 of you. Each opens once
you've beaten the one before it.

| Biome | Its Rift | The ladder (threat, favourite gear) |
|---|---|---|
| Ashfall | Thermal | Bombardiro Drago (I, Helmets) → Tung Tung Tung Sahur (III, Weapons) |
| Rimefrost | Cryo | Paperotti Gemelli (I, Boots) → Tralalero Tralala (II, Shields) → Frigo Camelo (III, Chest Suits) |
| Stormglass | Ion | Chimpanzini Bananini (I, Boots) → Gattini Gemellini (II, Gloves) → Cappuccino Assassino (III, Weapons) |
| Blightwood | Corrosive | Ranocchio Avocadino (I, Shields) → Brr Brr Patapim (III, Helmets) |

- **The threat** sets the boss's level (+0, +4, +8 over the last cave's),
  its health (0.85x, 1x, 1.2x) and its cache (see
  [arena-streaks.md](arena-streaks.md#boss-caches)). With your lead kaiju
  at level 10 the last cave is level 15, so a ladder reads LV 15, LV 19,
  LV 23.
- **Unlocking**: a win counts for everyone still in, joiners too
  (`profile.RiftBosses`, `{ [bossId] = wins }`, saved with the profile).
  The first win over a boss tells you what it opened: "Unlocked:
  Tralalero Tralala, next on this Rift's ladder."
- **Going in** (`RiftEnter`, vein, boss id): the server checks the pick
  (`RiftRun.canFight`). A locked boss: "Beat Paperotti Gemelli first." A
  boss from another biome's ladder: "That boss isn't behind this gate." No
  pick: the next boss you haven't beaten.
- **Alone at threat III** you're let in, and told: "You're in the Rift
  alone, against Frigo Camelo: it's built for 2 to 4 of you. Bring friends
  if you can."
- **Its fighters** (the caves' leaders and the boss's adds) are of the
  Rift's element (`RiftRun.pickFighters`).

### First bosses: Chimpanzini Bananini and Bombardiro Drago

*2026-10-23.* The first rung of the Ion and Thermal ladders is built for a
new miner on their own, at **level 2** (`Starter` on their
`DungeonRules.Bosses` entries: `{ Level = 2, Health = 0.6, Foes = 1 }`):

- **Levels**: the caves' critters, their leaders, the boss and its adds are
  never over level 2 (`RiftRun.level` and `bossLevel` with the boss), however
  strong the runners' kaiju. The card reads LV 2.
- **Fewer of them**: one critter fewer a cave (never under three, one for
  each of your kaiju), one leader a
  cave at gear tier 1, and no big Rift Brutes (`foeCount`, `fighterCount`,
  `fighterTier`, `pickFoes`).
- **A gentler boss**: 0.6x the health of any other threat I boss.
- **Recommended solo**: the card says RECOMMENDED SOLO, the tips box FIRST
  BOSS · RECOMMENDED SOLO, LV 2, and there's no "going alone" warning
  (`RiftRun.solo` is false for them). Going in: "Chimpanzini Bananini: a
  first boss, recommended solo at level 2. You've got this."

### Elements: come prepared

Every boss now says what to bring (`DungeonRules.elementTips`):

1. *Bombardiro Drago is THERMAL.*
2. *Gems give you protection: THERMAL gems in your armor resist its hits.*
3. *To defeat it, enchant with CRYO: a CRYO gem in your sword hits it for +25%.*
4. *Careful: its hits do +63% to CRYO armor.*

- **At the gate and Brutus's counter**, the boss you pick has a box in its
  element's colour, headed WEAK TO CRYO, with lines 2 to 4.
- **Going in**, lines 2 and 3 as notices; **as the boss comes through**,
  lines 3 and 4.
- **Bosses bite the wrong armor**: a boss's hit on a miner whose main armor
  element its own beats (the 125% everyone's weakness takes) lands 1.3x
  harder again (`DungeonRules.bossHit`, `BossWeak`; about +63% in all), in
  the Rift and in the party dungeon. The first such hit, and one every 20
  seconds after, says so: "Bombardiro Drago's THERMAL hits your CRYO armor
  hard: put THERMAL gems in your armor to resist it."

## The way

The world is built for each trip, far off in the dark, and gone with it
(`RiftWorld.build`).

- **Its layout** is the pathway dungeon's: the landing, 4 caves, then the
  throne cave, each on a grid cell next to the one before, and the path
  never runs beside itself (`RiftRun.layout`). The first step is always
  straight ahead of the landing.
- **Caves** are 76 studs across (the throne cave 96), floored with basalt
  and glowing cracks, and **walled all round**: rock faces 34 studs high,
  boulders at their feet, jagged crowns, the odd ledge and glowing seam.
  There is nowhere to fall and no lava.
- **Passages** 22 studs wide join them, walled too, under a rock arch with
  fangs.
- **Walls of fire** bar the passage out of each cave until its pack is down.
- **The sky** (`Sky`): a burning scar across it, strands of light, 14
  low clouds lit from below, and ash falling (`Ash`).
- Through the floor somehow (20 studs under it), you're put back in the
  last cave you reached, unhurt.

## Each boss's realm

*2026-10-23.* Every boss's trip is built in a realm of its own
(`Shared.RiftRealms`), hellish still, but in its element and **built
differently** from every other's (`Server.World.RiftStyles`): its walls,
its floor, the barrier across each passage, the lamps in the corners, the
arch over each passage and its throne are each of a kind no other realm
has, its sky one of four, and the colours, the fire, the clouds and what
falls from the sky are its own. Set pieces of its own stand by the walls
of every cave besides (never in the middle, which is for the fight). Each
runner's screen lights the air the realm's way (`RiftClient.hellLighting`,
from the `RiftRealm` attribute the server sets).

![The ten realms: the throne cave and a cave of each. Offline renders of the game's parts on a lit stage, not Roblox screenshots](rift/realms.jpg)

| Boss | Realm | Walls | Floor | Barrier | Lamps | Arch | Throne | Sky | Set pieces |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bombardiro Drago (Fire) | **The Crater Flats** | Rock, boulders, obsidian crowns, lava seams | Basalt with lava cracks | A wall of fire | Braziers | Rock, fangs hanging | A dais in a crater under a dragon's skull, the one bomb that never went off stood behind | A scar torn across it | Craters, dud bombs |
| Tung Tung Tung Sahur (Fire) | **The Burning Grove** | Charred logs leaning on black rock, stumps smouldering along the top | Scorched, cinders and embers | Burning logs stacked across the way | Skulls on stakes, burning | A burnt beam, embers hanging | A great stump, three log heads on stakes, the nailed bat, fire in the hollow | A scar | Burning trunks, fallen logs |
| Paperotti Gemelli (Frost) | **The Frozen Pond** | Ice tiled over blue rock, snow banked on top, icicles | A frozen lake, white cracks, dark deeps | Icicles down across the way | Ice lanterns | An ice arch, icicles | A nest of ice shards with two great eggs in it, a fountain frozen behind | An aurora | Ponds, hail, slabs |
| Tralalero Tralala (Frost) | **The Frozen Tide** | Sea rock with coral fans, a wave frozen breaking over the top | A tide flat, tide lines, ripples | A wave frozen as it curled over the way | Anemones | A wave curling over | A wave frozen over the seat, fins either side, a sneaker the size of a boat washed up behind | An aurora | Crests, fins |
| Frigo Camelo (Frost) | **The Freezer** | Steel panels, frost in the seams, racks of frozen things | A steel grate, frost | A freezer door, slats down | Cold tubes on posts | A steel lintel with a cold tube | A fridge the height of the wall, its door hanging open on cold light and shelves of things gone bad | An aurora | Ice blocks with things in them, icicles |
| Chimpanzini Bananini (Shock) | **The Charged Jungle** | Mossy trunks side by side, canopy over the top, crackling vines | Soil, moss, sparks | A lattice of vines with current in it | Tesla poles | Canopy, vines hanging | A banana split open for a seat under a palm wired with current | A storm, bolts frozen in it | Vines, charged trunks, bananas |
| Gattini Gemellini (Shock) | **The Static Spires** | Violet prisms at every angle, static arcing between them, spikes on top | Dark shard, yellow fissures | A field of static between two pylons | Crystal clusters | A crystal arch | A cat tower of crystal platforms, two pairs of eyes lit at the top | A storm | Spires, arcs |
| Cappuccino Assassino (Shock) | **The Blade Roost** | Timber frames with paper panels, katanas through them, a tiled roof | Boards, coffee stains | A curtain of blades | Paper lanterns | A torii, lanterns hanging | A cracked cup the size of a hut, steaming, a katana through the saucer | A storm | Blades, kunai |
| Ranocchio Avocadino (Poison) | **The Bog** | Mud held by tangled roots, slime in the gaps | Mud, puddles | Marsh gas, bubbles rising through it | Gas lamps on reeds | Roots arched over | Half an avocado on a lily pad in a pool, its pit glowing, reeds round | A spore moon | Pools, reeds, mounds |
| Brr Brr Patapim (Poison) | **The Rotting Grove** | A palisade of dead trunks, fungus shelved up them, roots hanging | Leaf litter, moss | Thorned roots woven across | Toadstools | A bough, roots and fungus hanging | A hollow dead tree, the seat in its mouth lit green, roots spread round | A spore moon | Dead trees, toadstools |

The frost realms' floors are ice. A trip is 1,350 to 1,650 parts.

## The fallen

Crews went in before you and didn't come back. What's left of them lies in
the caves, and more of it round the throne (`Server.World.FallenMiners`,
props only: you walk through them, nothing to press):

![Round the throne: miners fallen by its walls and their heap beside it. Offline render of the game's parts, not a Roblox screenshot](rift/fallen-throne.jpg)

| | |
| --- | --- |
| ![The heap by the throne: rubble, helmets, two up on spikes, bones, picks, a torn banner, spilt gems](rift/fallen-heap.jpg) | ![One slumped against a cave wall, its pick across its lap, a gem still glowing by its hand](rift/fallen-cave.jpg) |

- **Each one is a real miner** (since 2026-10-23): the body every player
  wears (`Server.Systems.FighterRig`) in the gear every player wears, built
  by the real `Equipment`, rolled at random for each of them by
  `Server.Systems.FallenCrew`: a helmet, chest, gloves, boots and shield
  from the **armor families players wear today** (Prospector, Skirmisher,
  Juggernaut, any rarity: `FallenCrew.Weights` 35/30/20/10/5, better than
  a fresh roll's commons), and **a sword** (`Traits.rollable`: the
  standard swords and their variants; no axes, hammers, lances, pistols or
  retired models), a gem in a piece or two, and for looks a suit on some
  (45%), a weapon skin (35%), a visor (40%) or a helmet skin (25%), rolled
  one by one, so about one in six wears nothing for looks and no two lie
  alike. Round it: its pick, a pouch of gems spilt and glinting (one lights
  the floor), the floor stained dark under it, and crystals of the place
  grown up through it.
- **Its sword lies on the floor by its hand** (`FallenMiners.dropWeapon`):
  out of its grip, flat, hilt by the hand and blade pointing away from the
  body, turned a little either way. The gear's Weapon model is read in the
  hand's frame to find the blade's long axis and its flat, so any sword
  lies right whichever way it was gripped; its lowest edge sits on the
  floor, and nothing welds it to the hand any more.
  Three ways they lie, the body's joints bent and every welded piece of
  gear carried along on its limb:
  - **Curled** on its side by a wall, knees drawn up, the lower arm
    stretched out along the floor, the upper arm fallen across its body,
    head dropped to its chest. (It leans back a little, so the shoulder it
    lies on sits on the floor, not through it.)
  - **Face down**, one arm stretched out for the pick it dropped, one knee
    drawn up, head turned to the side, claw marks where something dragged it.
  - **Sprawled** on its back, arms flung out, one knee up, head lolled to
    the side, its pick stood in the floor like a marker.
- Laid down, it's a prop: no Humanoid, every part anchored, nothing to bump
  into, and nothing on it moves or shines any more (no sparks off its suit,
  no glow from its gems: the only light is the spilt gem's).
- **Where**: 2 by the walls of each cave (`Count.Cave`), never in the way
  through; 6 round the throne (`Count.Throne`), clear of the throne, the way
  home and the heap. None on the landing.
- **The heap** beside the throne: rubble, three old helmets, bones, a
  skull, two picks stuck in it, a torn crew banner on a pole, two more
  helmets up on spikes either side, gems spilt round its foot, claw marks.
- In the Rift their glow is ember and the claw marks blood red. **The
  pathway dungeon** has them too: one in each room, glowing its element's
  colour, 4 and the heap in the boss's room.

![Six of them in a line, each in family armor of its own with its sword dropped on the floor beside it. Offline render of the game's parts, not a Roblox screenshot](rift/fallen-lineup.jpg)

![Closer: one curled on its side, its sword flat on the floor by its hand, hilt at the hand and blade pointing away. Offline render, not a Roblox screenshot](rift/fallen-miners.jpg)

![Sprawled on its back and face down, each with its sword on the floor beside it. Offline render, not a Roblox screenshot](rift/fallen-facedown.jpg)

**How the body gets there.** `FallenMiners` is a world builder and knows
nothing of gear; the server hands it bodies through `FallenMiners.dresser`
(set by `FallenCrew.start()` in `Main.server`, before any world is built).
`FallenMiners.place` asks for one, lays it down (`lay`: every part
anchored first, so that in a live place each moves alone rather than
dragging the whole welded assembly with it; then the root to the pose's
frame, each joint from its parent through its Motor6D with the pose's
bend, then everything welded to a limb back where it sat on it)
and keeps the old expedition-suit prop as the stand-in when there's no
body to be had (the world tests build without one, so their part counts
stay what they were). A laid-out miner is about 300 to 410 parts
(its armour and, on a suit, its trim seams), so a trip with 14 of them
carries a few thousand more parts than before; that is the cost of real
kits, and `Count` is where to trim if a device struggles.

### What drops what

Critters never drop armor. In the Outpost they pay your kaiju EXP and coins
(and a robber carries off your gem). In the Rift and the dungeon, critters
and fighters drop nothing on the way; the boss at the end drops a cache
(two pieces of gear, keep one), and the Rift pays coins and
kaiju EXP when you clear it. Mining pays gems only. Armor otherwise comes
from the lottery (every roll leaves a piece for the Market) and the Market.

## A trip

The rules are `Shared.RiftRun`; the server is `Server.RiftServer`.

| | |
| --- | --- |
| **Your kit** | Your combat kit comes out as you go through and stays out until you're home (`SparServer.riftKit`: hunting, as in the Outpost). You can't put it away in there: "Your kit stays out in the Rift." |
| **Packs** | Each cave's pack comes up when the first runner walks in, not before. **Every one of it comes through a tear of its own** in the cave's floor, in the critters' world's colours (the Outpost's tears, `RiftTear`, Hell palette): one opens every 0.45 seconds, at least 9 studs from the others and from any runner. The critters come first, leaping out at the nearest runner, then their leaders through taller tears (10 studs). Until the last is through, the pack is on its way: the strip counts it in foes left, and the cave can't clear |
| **Critters** | 3, 4, 4, 5 in caves 1 to 4 (never fewer than a team of three kaiju), plus 1 for each runner past the first. Brainrot critters from the Outpost's roster; a ranged one only at the back |
| **Big ones** | From cave 2, a 60% chance that one of the critters is a **Rift Brute**: 4x health, 1.5x damage, longer reach |
| **Fighters** | The pathway dungeon's regular fighters lead each pack (`Duelist.spawnDungeon`; `RiftLeader` on their models): 1, 1, 2, 2 in caves 1 to 4, plus one for every two runners past the first, armed and armoured to gear tier 1, 2, 2, 3, each with 1.5x a room fighter's health. One of the dungeon's roster per cave, with its element and moves. Anyone in the trip can hit them and be hit by them, kaiju too |
| **Level** | The critters come at your team's level (the average of the runners' lead kaiju), +2 in cave 1, +1 more per cave. The boss's level is the last cave's, +0, +4 or +8 by its threat (I, II, III: `RiftRun.bossLevel`), and its adds come at it. The gate shows it, worked out from your party's lead kaiju, and so does the strip at the throne (**THRONE CAVE · FRIGO CAMELO · LV 17**). Capped at 30 |
| **Caches** | Clear a cave (critters and fighters) and everyone in finds a gem (`RiftCache`, "Found in the Rift"), 12% luckier in cave 1 and 6% more each cave |
| **The boss** | The one you picked at the gate, from its biome's ladder, as the pathway dungeon's **Colossus**: its boss fighter with every one of its moves, gear tier 4 alone or 4 to 5 in a party, and 1.8x a Colossus's health (+50% per extra runner), times its threat's (0.85x, 1x, 1.2x for threat I, II, III: `Shared.BossLoot`). It tears through (a 16-stud tear) when the first runner reaches the throne cave; it's its cave's leader. At 66% and 33% health it calls 3 critters and a tier-3 fighter through, each through a tear of its own |
| **Beaten** | Everyone still in: 300 coins + 40 per cave, a lucky cache, 120 EXP for their kaiju, and swings back on their pick (the dungeon restore). Anyone down gets up. The way home opens and everyone gets a **boss cache** |
| **Its loot** | A boss cache each, no sharing and no rolling against each other: the Arena Cache's roll and pick (see [arena-streaks.md](arena-streaks.md#boss-caches)), headed **RIFT BOSS DEFEATED · THREAT II** and the boss's name. Inside: two pieces of gear to keep one of, rolled by how much you've played 1v1 and at least the boss's threat's floor (Uncommon, Rare, Ultra-Rare), one of them the boss's favourite kind. The other goes up on the Market from the **Rift Vault**, with your 25% cut. It opens a few seconds after the kill; LATER keeps it for whenever you like (the **BOSS CACHE READY** button) |
| **Home** | 20 seconds after the kill, everyone still in is home |

Once the boss is down the strip says **BOSS DOWN · HOME IN 0:20**.

### Who takes whom

**The boss takes turns.** A boss (and a raid boss) picks who it's on by
threat (`Shared.Aggro`): each player's damage, and now **each kaiju's own**
(`KaijuServer.strike` adds a kaiju's blows to the enemy's threat under the
kaiju itself). After 8 seconds on one target (`Aggro.RotateAfter`), whoever
else is hurting it at least half as much (`RotateShare`) takes a turn, so
it doesn't glue to the miner while their kaiju hit it for free; the usual
rules still apply (a new target held 1.5 s, overtaken by 10% up close or
30% from range, a weakened target drawing it). On a kaiju (`duel.PetTarget`)
it walks to it, swings at it and aims its shots at it (`KaijuServer.hurt`:
the kaiju may guard, parry or hop clear), its area moves hit the kaiju in
them too, and its player hears "Frigo Camelo turns on Pebble!".

**Everyone sees who it's on.** The boss names its target on its model
(`FocusKaiju`, the kaiju's id, else `FocusUserId`, the player: `Duelist`),
and every runner's screen (`Client.BossFocus`) hangs a red diamond over
that head with **TARGET** under it; over you it reads **ON YOU**, over one
of yours **ON YOUR KAIJU**, bigger, brighter and beating. Only the players
in that fight see the marks (its `RaidId`, `RiftRun` or `DungeonId` on
them too), only over the boss (a Rift boss, a dungeon's boss, a party
raid's), never a room's fighters. Its body turns to the same one: a boss on
a kaiju looks at the kaiju, not its owner (`BodyPoses`).

**Still to check in Studio** (the targeting itself runs on the real code
in `run_boss_targets`; these need eyes): with two players, a kaiju team
and a Rift boss, that the boss walks to and swings at the kaiju it turns
on and its head follows it; that a turn comes about every 8 seconds when
both the player and a kaiju keep hitting it; that the TARGET diamond sits
clear of the kaiju's health glow and the player's nameplate, and ON YOU /
ON YOUR KAIJU reads at phone size; that a knock-down recalls the kaiju
before the robbers arrive, and RESTORE or a backup coming through the gate
redeploys them without a second team appearing; and that the KNOCKED DOWN
overlay stays hidden while the Rift down card is up.

- **Your kaiju take the critters.** While any critter of the pack is about,
  your kaiju fight only critters, sharing them out (two on one if there
  are more kaiju than critters). Only once the critters are down do they
  turn on the leaders (`KaijuServer`).
- **You take the leader.** Your lock goes for the pack's leader first:
  - the nearest fighter, or the boss, in range and in sight (or hitting
    you), over any nearer critter;
  - once you're on a leader, critters coming nearer don't pull it off;
  - switching or tapping a target in the list still picks whoever you
    like (`TargetLockRules`).
- **The target list** marks them: **LEADER · their name**.

![A boss cache: Tung Tung Tung Sahur, threat III (offline render)](rift/loot.png)
![A threat I boss cache on a phone (offline render)](rift/loot_phone.png)

Your kaiju come with you: you keep the Outpost's attribute, so
`KaijuServer` keeps them out and follows you, jumping when you jump. They
fight the critters and the fighters alike. The Outpost's own critters,
stranded check and lobby healing leave you alone while you're in the Rift
(`RiftRun` attribute).

### The HUD

A strip at the top (claims the top slot like the other top bars): pips for
the caves and the throne, where you are, foes left, gems found and how many
are in.

![The Rift strip](rift/strip.png)

Your kit is out in the Rift as a matter of course, so the **KIT OUT · MINE**
bar (`SparKit`) stays down there: `refreshBar` hides it while `RiftRun` is
set. On a phone the kit switch by your thumb still swaps to the pick and
back, and on a computer 1 does. (It used to sit under the strip, where on
a phone it ran into the kaiju strip at the top right.)

On a phone the Rift strip keeps to the **top left**, under Roblox's
buttons, because the kaiju strip has the top right while your kit's out;
on a computer it stays centred. The old phone layout, with the strip
centred and the bar under it, is what the pictures below show:

| Before | Now |
| --- | --- |
| ![KIT OUT behind the strip](rift/kit-bar-before.png) | ![KIT OUT under the strip](rift/kit-bar-after.png) |

![On a phone](rift/kit-bar-phone.png)

### The arrows on the ground

When a cave's wall of fire goes out, the yellow arrows (`GroundGuide`) lead
you through it, a little way into the next cave (the gate's `Into`
attribute, set by `RiftWorld`). Once you're through, they stop. They used to
point at the gate itself for 15 seconds, so after you walked through they
turned round and pointed back the way you came. Once the boss is down they
lead to the way home.

## Going down

Down in the Rift works like down in the Outpost: with your kit out, a
finishing blow knocks you down (`SparDown`), it doesn't kill you. The
fighters leave you be while you're down; with everyone down, they wait.

- **On the way**: you stay down and the critters rob you (`Robbery`,
  `Frontier.Rob`):
  - the cave's critters within 70 studs come for you; if fewer are near
    than there's to take (up to 3), more leap out of Rift tears round you;
  - each grabs one of the gems you found in there, newest first ("A critter
    grabbed your Thermal Gem!"), holds it up and runs for a tear with it.
    Knock it out before it gets there and it drops the gem back to you
    ("Recovered."); the ones that get away are gone, and count as down for
    the cave;
  - your screen says **KNOCKED OUT · The critters are going through your
    pouch! · Back to base in 8**;
  - after 8 seconds (sooner once there's nothing left to take), you're back
    at base on your feet, and a card tells you what they took.

![What the critters took: the card. Offline render of the game's UI code, gems drawn as stand-ins, not a Roblox screenshot](rift/robbed.png)

  The card (`RobReport`): **ROBBED!**, each gem they grabbed in 3D with its
  name in its rarity's colour and **GONE**, or **SAVED** if you knocked it
  loose again. With nothing on you to take: **NOTHING TAKEN**.
- **At the boss**: you stay down and choose.

![Down at the boss](rift/down.png)

  The card is two columns. On the left, what you can do for yourself; on
  the right, **CALL FOR BACKUP**: the gate's lobby again, down there.

  - **RESTORE · 150 COINS**: you and your kaiju, every one of them, back to
    full health right there (`KaijuServer.restoreAll`). It doubles each
    time in a trip (150, 300, 600...). Coins only, no Robux;
  - **BACK TO BASE**: home with the gems you found;
  - **Your kaiju are called back** the moment you go down (into their
    Gemsouls: `KaijuServer.recallTeam`), so they're not left fighting
    without you. Restored, or got up by backup coming through, they come
    out again beside you at once, **in danger or not** (`deployTeam` with
    `force`: the one place DEPLOY is allowed in a fight);
  - **CALL FOR BACKUP · 1/4 IN YOUR PARTY**: a list of who you can call in
    (`Shared.RiftLobby.backup`): the rest of your party first (with you in
    the Rift, or where they are in the Outpost, no button), then every
    miner in the Outpost, then your Roblox friends online, each once, with
    their face, name and level. **INVITE** asks a miner into your party
    (`PartyInvite`, as the gate does); a friend who isn't in the game gets
    Roblox's invite (**INVITE ↗**). Asked a moment ago: **INVITED**; in a
    party or the Rift already: **IN A PARTY** / **IN THE RIFT**. Only your
    party's leader can invite (the card says so otherwise), and a full
    party has nobody to ask. The list redraws by itself as people come and
    go. Whoever accepts walks up to any Rift Gate (or the bounty counter)
    and comes through to your trip: joining is allowed **at the throne
    too** now, while the boss still stands (`RiftServer.partyRun`), not
    only on the path;
  - a party member coming through the gate while you're down **gets you up
    for nothing**: full health, kaiju out again, no RESTORE spent;
  - nothing chosen in 60 seconds: back to base.

**BACKUP, anywhere on the way**: the strip's **BACKUP** chip opens the
same list on its own (`RiftClient.openBackup`), in any cave, so a party
can be called in before the boss, not only once you're down. Down on the
way you're still robbed and sent home (above): call backup before that.

  Your kaiju fight on without you while you're down.

## Healing crystals

Green crystals grow in the corners of every cave and the throne cave, 2 a
cave (`RiftRun.Heal`, `RiftRun.healSpots`, `RiftWorld.healRock`). They're
for healing, not gems:

![A healing crystal in a cave corner. Offline render of the game's parts, not a Roblox screenshot](rift/heal.png)

- Their label reads **HEALING CRYSTAL**, their prompt **Click to heal**.
- Swap to your pick (**1**, or the kit button on phones) and mine one:
  each swing heals you 7%; the swing that breaks it (5 swings) heals you
  25% more and your kaiju that are up 35% ("The crystal breaks open: you
  and your kaiju feel stronger."). It grows back in 40 seconds.
- Not while you're down, and only from 10 studs.

The Outpost has them too: 8 of its rocks are healing crystals
(`Outpost.Heal`: `Count` 8, at least `Apart` 38 studs from each other).
They're picked from the welcome field first, then out across the quarry,
so there's one near wherever you're mining. They heal by the same numbers
as the caves' crystals.

## Your kit and your pick

Your combat kit is out when you go in, but you can put it away: **1** on a
keyboard, or the **FIGHT / MINE** button on phones (at the bottom, left of
the middle, where it sits beside PLAY in the Outpost), swaps between your kit and your pick, here and in the Outpost alike
(`SparKit.toggle`, the server's `Hunt`). Not while you're down.

## Together

- Up to 4 in a trip. Party members can join through **any** gate while the
  trip is still on the way (not once it's at the boss).
- **Going in together.** The leader's **ENTER TOGETHER** (`RiftEnter`
  with `together`) takes every member who's ready in with them, from
  anywhere in the Outpost, up to 4 (they get the same **THE RIFT**
  crossing on their screen). A member who isn't ready, or can't go
  in just now, is told "Marc went through a Rift Gate: walk up to any
  gate to follow." A member's own **GO IN NOW** takes nobody in with
  them.
- The pack sizes, the fighters and the boss's health grow with each
  runner.
- While you're in the Rift, nothing else can start for you: spars, kaiju
  battles, duels and the duel queue, raids and the dungeon queue, the
  Arena and expeditions all answer "Leave the Rift first." or "Sam is in
  the Rift." (It would pull you out mid-trip.) Going in ends a spar you
  were in ("Sam went into the Rift.").

## Leaving

- **The way you came in**: the landing's opening (prompt **Go home**),
  keeping what you found.
- **The way home** in the throne cave opens once the boss is down.
- Leaving the game ends your trip.
- Your kit goes away when you're home.

## Where it lives

| File | What |
| --- | --- |
| `src/shared/RiftRun.luau` | The rules: the layout, packs and fighters, where their tears open (`Portal`, `portalSpots`), levels, the boss and its health, caches, rewards, robbery, RESTORE's price |
| `src/shared/BossLoot.luau` | Each boss's cache by its threat (its floor, quality, health), its favourite kind of gear |
| `src/server/World/RiftWorld.luau` | Builds a trip's world far off in the dark, in its boss's realm: walled caves, passages under arches, walls of fire, the throne cave, the ways home, the burning sky, the realm's set pieces (`RiftWorld.Features`); `RiftWorld.inside` (is a spot in a cave) |
| `src/shared/RiftRealms.luau` | Each boss's realm: how it's built (its Style), its colours, its sky, what falls from it, its set pieces' kind, its lighting |
| `src/server/World/RiftStyles.luau` | The kinds a realm is built from: ten walls (and corners), ten floors, ten barriers, ten lamps, ten arches, ten thrones, four skies |
| `src/server/World/FallenMiners.luau` | The fallen: `place` (one, in a pose), `heap` (by the boss), `scatter` (round a room, by the walls first, clear of the doors and of what it's told to avoid), `Count`; the dungeon's rooms use it too (`DungeonWorld`) |
| `src/server/Systems/RiftServer.luau` | Runs trips: `RiftEnter` (going in together: the ready members with their leader), `RiftLeave`, `RiftChoice`, `RiftPeek`; a boss cache each at the kill |
| `src/server/Systems/ArenaStreaks.luau` | `ArenaStreaks.bossCache`: rolls and saves a boss cache, and tells its owner |
| `src/server/Systems/KaijuServer.luau` | Your kaiju take the critters before the leaders |
| `src/shared/TargetLockRules.luau`, `src/client/Modules/TargetLock.luau` | Your lock takes the leader first |
| `src/client/Modules/FoeBars.luau` | **LEADER** in the target list |
| `src/server/Systems/FrontierServer.luau` | The tears (`open`: `Height`, `Hell`), through `KaijuWilds.rift` |
| `src/server/Systems/Duelist.luau` | The fighters and the Colossus (`spawnDungeon` with a Rift encounter: its runners are whoever's in the trip, kaiju can fight them, `HealthScale`) |
| `src/server/Systems/Dungeons.luau` | `Dungeons.bossGem`: the boss's gem, shared with the pathway dungeon |
| `src/server/Systems/SparServer.luau` | `SparServer.riftKit`: the kit out going in, away coming home |
| `src/client/Modules/RiftClient.luau` | The gate's lobby, the crossing, hell lighting, the strip, the down window |
| `src/shared/RiftLobby.luau` | The lobby's rules: the party's places, who's about and in what order, what each row offers |
| `src/client/Modules/SocialUI.luau` | Your party (`party`, `PartyChanged`), your friends online (`friends`, `FriendsChanged`), Roblox's invite (`inviteFriends`) |
| `src/client/Modules/StreakRewards.luau` | The cache screen: the roll, the picks, CLAIM (a boss cache's heading, threat and element) |
| `src/server/World/OutpostWorld.luau` | The gate on each vein (`veinMarks`) |
| `src/client/Modules/RiftTear.luau` | The tear in the gate, in the Hell palette |
| `src/server/Systems/KaijuWilds.luau` | `spawnBug` options for the Rift's critters (`Scale`, `Health`, `Damage`, `Reach`, `Title`, `Stay`, `Wander`) |

A runner carries `RiftRun`, `RiftRealm` (the boss's realm), `RiftRoom`, `RiftLeft`, `RiftBoss`,
`RiftBossLevel`, `RiftFound`, `RiftRunners`, `RiftWon`, `RiftExitAt`; when down at the boss
`RiftFallen` and `RiftRestore`. A boss cache is saved with the player's
Arena Caches (`profile.Duel.StreakCaches`, `Kind = "Boss"`).

## Spanish

Every line above is in `Shared.LangEs`: the lobby (its places, tabs, rows,
buttons and hints), the warning, the strip,
the down window, the boss cache, the server's messages and the prompts.
Boss and move names stay in English (they're names).

## Tests

| Suite | What it checks |
| --- | --- |
| `run_rift` | 47,784 checks: the gate's lobby (on your own; the Outpost's rows in order and what each offers; your friends here, elsewhere in the game and online; INVITED; a member's party and a full one; your party already in there); the ladders (every boss on one ladder of its element, threats rising, the first built for one and the last for 2 to 4, locks, the next boss, levels rising and capped, fighters of the Rift's element), pack sizes (never fewer critters than a team of kaiju), where the tears open (spread, clear of the runners, on the cave's floor, one for each even when crowded), fighters and their gear, levels, the elite, every boss picked over many draws and each with its moves, the boss's gear tier and health, each boss's threat and favourite gear (its health and cache by threat), adds, caches, rewards, robbery, RESTORE's price, the solo warning, the layout. The world over many trips: walled caves you can't walk out of, floor all the way, arches you fit under, walls of fire at the passages that open (each leading a little way into the next cave), the ways home, no lava, the sky, parts per trip (1,400 with the realm's set pieces). Each boss's realm: a trip built in each of the ten, marked with it, its walls, floor, barrier, lamps, arch and throne each of a kind no other realm has, its sky one of four, its walls across the passages a colour no other realm's are, its rock its own, its fire in its colour, its set pieces in the caves, its sky burning and its ash its own, every barrier solid with its curtain and fires, every arch clear of the floor, the throne lit, the middle of every cave clear, lights and fire enough; the client lights the realm you're in and the server builds the boss's. The fallen: 2 in each cave and more round the throne, none on the landing, the heap by the throne, every part one you walk through, none in the way through or the way home, a pose each; scattered alone, by the walls first, clear of what to avoid and of the doorway; in a dungeon, one a room, more and the heap in the boss's. And nothing else starts for a runner |
| `run_fallen_miners` | The fallen miners as real miners: 40 kits rolled (whole kits of real catalogue gear, 24 chests, 25 weapons, no pistols, rolls and gems on them; suits, weapon skins, visors and helmet skins of the right kind, owned, and some with nothing); six laid down in the three poses (dressed, no Humanoid, no joints, 20+ gear parts, every part anchored and walk-through, lying low with the head near the floor, slumped sat up, every welded piece still on its limb, the stain under it, the pose recorded); the old suit when no body is handed over |
| `run_boss_targets` | 29 checks on the real `raidTarget` and `foeRoot`, cut out of Duelist's source and driven through a Rift fight (two runners, a kaiju, the real `Shared.Aggro`): it opens on the duel's player; a kaiju out-damaging everyone draws it (`PetTarget`, the owner stays the duel's player and hears "turns on Pebble!"); after `RotateAfter` the other runner hurting it half as much takes a turn (the duel's player and `RivalOwner` follow, "turns on you!"); a called-back kaiju is no target however much it hurt it; a downed runner is no target, so a redeployed kaiju is; a knocked-out kaiju hands the foe back to its owner; everyone down, it waits; a runner leaving is dropped and the last one leaving ends it, with no raid-style notice |
| `run_boss_focus` | 26 checks: which creature is a fight's boss (a Rift boss, a dungeon's boss, a party raid's; not a room's fighters or an Arena rival), who sees its mark (the players in its raid, trip or dungeon, nobody else), the words over you, your kaiju and the rest, your mark's beat and the others' stillness, and the wiring (the server names the kaiju it's on by id, the body faces it, the lobby and combat scripts start the marks, the Spanish is there) |
| `run_kaiju` (`kaiju_server_cases`) | Whole trips on the server: going in with the kit out, packs coming up as you walk in, each foe through a tear of its own (critters first, leaders through taller ones, spread out, a moment apart, in the Rift's colours), counted on the strip while on their way and the cave not clearing before they're through, the leaders marked, your kaiju taking critters before a leader and the leader once they're gone, the boss through its own tear and its adds through theirs, a wall opening, caches, the floor, robbery on the way, the Colossus and its adds, down at the boss, RESTORE, BACK TO BASE, joining a party, winning, a boss cache each (two pieces to keep one; alone or in a party; no claim, roll or pass), the clock home starting at the kill, the kit away at home. The ladder: the gate's peek (its biome's element, the ladder, the next boss, each boss's level at your kaiju's and rising, locks, a portrait each), a locked boss, an unknown one and another biome's refused, the gate's first boss and its element's fighters, a joiner seeing the party's boss, a win tallied for everyone and the next boss unlocked and offered, the top boss alone allowed and warned. Going in together: a ready member brought in from far off, one not ready told they can follow, a member going in bringing nobody. The fighters are stand-ins here: the real Duelist isn't loaded |
| `run_target_lock` | Your lock takes a pack's leader over nearer critters and those attacking you, holds it against them, takes it back from a critter, but not hidden or out of range; a target you pick still holds |
| `run_spar` | Going into the Rift ends a spar, the kit stays out in there and can't be put away, nobody spars with a runner, and the kit goes away at home |
| `run_outpost` | Each vein has its gate, prompt, arch, glow, cracks in its colour and its index |
| `run_lang` | The gate in Spanish: the lobby's lines, its biome and element, the ladder's heading and lines, a locked card, BRING FRIENDS and its warning, an unlock, joining your party, the strip's level |
| `run_topbar` | The crossing is a cover; the card, strip and down window keep clear of Roblox's buttons |
